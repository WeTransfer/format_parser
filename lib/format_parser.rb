require 'set'
require 'measurometer'

# A pretty nimble module for parsing file metadata using partial reads. Contains all the
# top-level methods of the library.
module FormatParser
  require_relative 'format_parser/version'
  require_relative 'hash_utils'
  require_relative 'attributes_json'
  require_relative 'image'
  require_relative 'audio'
  require_relative 'document'
  require_relative 'video'
  require_relative 'archive'
  require_relative 'io_utils'
  require_relative 'read_limiter'
  require_relative 'read_limits_config'
  require_relative 'remote_io'
  require_relative 'io_constraint'
  require_relative 'utf8_reader'
  require_relative 'care'
  require_relative 'active_storage/blob_analyzer'
  require_relative 'text'
  require_relative 'string'

  # Define Measurometer in the internal namespace as well
  # so that we stay compatible for the applications that use it
  const_set(:Measurometer, ::Measurometer)

  # Is used to manage access to the shared array of parser constructors, which might
  # potentially be mutated from different threads. The mutex won't be hit too often
  # since it only locks when adding/removing parsers.
  PARSER_MUX = Mutex.new
  MAX_BYTES_READ_PER_PARSER = 1024 * 1024 * 2

  # The value will ensure the parser having it will be applied to the file last.
  LEAST_PRIORITY = 99

  # Register a parser object to be used to perform file format detection. Each parser FormatParser
  # provides out of the box registers itself using this method.
  #
  # @param callable_parser[#call] an object that responds to #call for parsing an IO
  # @param formats[Array<Symbol>] file formats that the parser provides
  # @param natures[Array<Symbol>] file natures that the parser provides
  # @param priority[Integer] whether the parser has to be applied first or later. Parsers that offer the safest
  #   detection and have the most popular file formats should get a lower priority (0 or 1), the default
  #   priority is 99. Before parsing parsers get sorted according to their priority value ascending, so parsers
  #   with a lower priority value will be applied first, and if a single result is requested, will also return
  #   first.
  # @return void
  def self.register_parser(callable_parser, formats:, natures:, priority: LEAST_PRIORITY)
    parser_provided_formats = Array(formats)
    parser_provided_natures = Array(natures)
    PARSER_MUX.synchronize do
      # It can't be a Set because the method `parsers_for` depends on the order
      # that the parsers were added.
      @parsers ||= []
      @parsers << callable_parser unless @parsers.include?(callable_parser)
      @parsers_per_nature ||= {}
      parser_provided_natures.each do |provided_nature|
        @parsers_per_nature[provided_nature] ||= Set.new
        @parsers_per_nature[provided_nature] << callable_parser
      end
      @parsers_per_format ||= {}
      parser_provided_formats.each do |provided_format|
        @parsers_per_format[provided_format] ||= Set.new
        @parsers_per_format[provided_format] << callable_parser
      end
      @parser_priorities ||= {}
      @parser_priorities[callable_parser] = priority

      @registered_natures ||= []
      @registered_natures |= parser_provided_natures
      @registered_formats ||= []
      @registered_formats |= parser_provided_formats
    end
  end

  def self.registered_natures
    @registered_natures
  end

  def self.registered_formats
    @registered_formats
  end

  # Deregister a parser object (makes FormatParser forget this parser existed). Is mostly used in
  # tests, but can also be used to forcibly disable some formats completely.
  #
  # @param callable_parser[#==] an object that is identity-equal to any other registered parser
  # @return void
  def self.deregister_parser(callable_parser)
    # Used only in tests
    PARSER_MUX.synchronize do
      (@parsers || []).delete(callable_parser)
      (@parsers_per_nature || {}).values.map { |e| e.delete(callable_parser) }
      (@parsers_per_format || {}).values.map { |e| e.delete(callable_parser) }
      (@parser_priorities || {}).delete(callable_parser)
    end
  end

  # Parses the resource at the given `url` and returns the results as if it were any IO
  # given to `.parse`. The accepted keyword arguments are the same as the ones for `parse`.
  #
  # @param url[String, URI] the HTTP(S) URL to request the object from using `Range:` requests
  # @param headers[Hash] (optional) the HTTP headers to request the object from
  # @param kwargs the keyword arguments to be delegated to `.parse`
  # @see {.parse}
  def self.parse_http(url, headers: {}, **kwargs)
    # Do not extract the filename, since the URL
    # can really be "anything". But if the caller
    # provides filename_hint it will be carried over
    parse(RemoteIO.new(url, headers: headers), **kwargs)
  end

  # Parses the file at the given `path` and returns the results as if it were any IO
  # given to `.parse`. The accepted keyword arguments are the same as the ones for `parse`.
  # The file path will be used to provide the `filename_hint` to `.parse()`.
  #
  # @param path[String] the path to the file to parse on the local filesystem
  # @param kwargs the keyword arguments to be delegated to `.parse`
  # @see {.parse}
  def self.parse_file_at(path, **kwargs)
    File.open(path, 'rb') do |io|
      parse(io, filename_hint: File.basename(path), **kwargs)
    end
  end

  # Parses the resource contained in the given IO-ish object, and returns either the first matched
  # result (omitting all the other parsers), the first N results or all results.
  #
  # @param io[#seek, #pos, #read] an IO-ish object containing the resource to parse formats for
  # @param natures[Array] an array of file natures to scope the parsing to.
  #   For example `[:image]` will limit to image files.
  #   The default value is "all natures known to FormatParser"
  # @param formats[Array] an array of file formats to scope the parsing to.
  #   For example `[:jpg, :tif]` will scope the parsing to TIFF and JPEG files.
  #   The default value is "all formats known to FormatParser"
  # @param results[:first, :all] one of the values defining how many results to return if parsing
  #   is ambiguous. The default is `:first` which returns the first matching result. `:all` will return all results.
  #   When using `:first` parsing will stop at the first successful match and other parsers won't run.
  # @param limits_config[ReadLimitsConfig] the configuration object for various read/cache limits. The default
  #   one should be good for most cases.
  # @param filename_hint[String?] the filename. If provided, the first parser applied will be the
  #   one that responds `true` to `likely_match?` with that filename as an argument. This way
  #   we can optimize the order of application of parsers and start with the one that is more likely
  #   to match.
  # @return [Array<Result>, Result, nil] either an Array of results, a single parsing result or `nil`if
  #   no useful metadata could be recovered from the file
  def self.parse(io, natures: @parsers_per_nature.keys, formats: @parsers_per_format.keys, results: :first, limits_config: default_limits_config, filename_hint: nil)
    # Limit the number of cached _pages_ we may fetch. This allows us to limit the number
    # of page faults (page cache misses) a parser may incur
    read_limiter_under_cache = FormatParser::ReadLimiter.new(io, max_reads: limits_config.max_pagefaults_per_parser)

    # Then configure a layer of caching on top of that
    cached_io = Care::IOWrapper.new(read_limiter_under_cache, page_size: limits_config.cache_page_size)

    # How many results has the user asked for? Used to determinate whether an array
    # is returned or not.
    amount = case results
             when :all
               @parsers.count
             when :first
               1
             else
               throw ArgumentError.new(':results does not match any supported mode (:all, :first)')
             end

    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    parsers = parsers_for(natures, formats, filename_hint)

    # Limit how many operations the parser can perform
    limited_io = ReadLimiter.new(
      cached_io,
      max_bytes: limits_config.max_read_bytes_per_parser,
      max_reads: limits_config.max_reads_per_parser,
      max_seeks: limits_config.max_seeks_per_parser
    )

    results = parsers.lazy.map do |parser|
      # Reset all the read limits, per parser
      limited_io.reset_limits!
      read_limiter_under_cache.reset_limits!

      # We need to rewind for each parser, anew
      limited_io.seek(0)
      execute_parser_and_capture_expected_exceptions(parser, limited_io)
    end.reject(&:nil?).take(amount)

    # Convert the results from a lazy enumerator to an Array.
    results = results.to_a

    Measurometer.increment_counter('format_parser.unknown_files', 1) if results.empty?

    amount == 1 ? results.first : results
  ensure
    cached_io.clear if cached_io
  end

  # We need to apply various limits so that parsers do not over-read, do not cause too many HTTP
  # requests to be dispatched and so on. These should be _balanced_ with one another- for example,
  # we cannot tell a parser that it is limited to reading 1024 bytes while at the same time
  # limiting the size of the cache pages it may slurp in to less than that amount, since
  # it can quickly become frustrating. The limits configurator computes these limits
  # for us, in a fairly balanced way, based on one setting.
  #
  # This method returns a ReadLimitsConfig object preset from the `MAX_BYTES_READ_PER_PARSER`
  # default.
  #
  # @return [ReadLimitsConfig]
  def self.default_limits_config
    FormatParser::ReadLimitsConfig.new(MAX_BYTES_READ_PER_PARSER)
  end

  def self.execute_parser_and_capture_expected_exceptions(parser, limited_io)
    parser_name_for_instrumentation = parser.class.to_s.split('::').last.underscore
    Measurometer.instrument('format_parser.parser.%s' % parser_name_for_instrumentation) do
      parser.call(limited_io).tap do |result|
        if result
          Measurometer.increment_counter('format_parser.detected_natures', 1, nature: result.nature)
          Measurometer.increment_counter('format_parser.detected_formats', 1, format: result.format)
        end
      end
    end
  rescue IOUtils::InvalidRead
    # There was not enough data for this parser to work on,
    # and it triggered an error
    Measurometer.increment_counter('format_parser.invalid_read_errors', 1)
  rescue IOUtils::MalformedFile
    # Unexpected input was encountered during the parsing of
    # a file. This might indicate either a malicious or a
    # corruped file.
    Measurometer.increment_counter('format_parser.malformed_errors', 1)
  rescue ReadLimiter::BudgetExceeded
    # The parser tried to read too much - most likely the file structure
    # caused the parser to go off-track. Strictly speaking we should log this
    # and examine the file more closely.
    # Or the parser caused too many cache pages to be fetched, which likely means we should not allow
    # it to continue
    Measurometer.increment_counter('format_parser.exceeded_budget_errors', 1)
  ensure
    limited_io.send_metrics(parser_name_for_instrumentation)
  end

  # Returns objects that respond to `call` and can be called to perform parsing
  # based on the _intersection_ of the two given nature/format constraints. For
  # example, a constraint of "only image and only ZIP files" can be given -
  # but would raise an error since no parsers provide both ZIP file parsing and
  # images as their information.
  #
  # @param desired_natures[Array] which natures should be considered (like `[:image, :archive]`)
  # @param desired_formats[Array] which formats should be considered (like `[:tif, :jpg]`)
  # @param filename_hint[String?] the filename hint for the file. If provided,
  #     the parser that likely matches this filename will be applied first.
  # @return [Array<#call>] an array of callable parsers
  # @raise ArgumentError when there are no parsers satisfying the constraint
  def self.parsers_for(desired_natures, desired_formats, filename_hint = nil)
    assemble_parser_set = ->(hash_of_sets, keys_of_interest) {
      hash_of_sets.values_at(*keys_of_interest).compact.inject(&:+) || Set.new
    }

    fitting_by_natures = assemble_parser_set[@parsers_per_nature, desired_natures]
    fitting_by_formats = assemble_parser_set[@parsers_per_format, desired_formats]
    parsers = fitting_by_natures & fitting_by_formats

    raise ArgumentError, "No parsers provide both natures #{desired_natures.inspect} and formats #{desired_formats.inspect}" if parsers.empty?

    # Order the parsers according to their priority value. The ones having a lower
    # value will sort higher and will be applied sooner
    parsers_in_order_of_priority = parsers.to_a.sort do |parser_a, parser_b|
      if @parser_priorities[parser_a] != @parser_priorities[parser_b]
        @parser_priorities[parser_a] <=> @parser_priorities[parser_b]
      else
        # Some parsers have the same priority and we want them to be always sorted
        # in the same way, to not change the result of FormatParser.parse(results: :first).
        # When this changes, it can generate flaky tests or event different
        # results in different environments, which can be hard to understand why.
        # There is also no guarantee in the order that the elements are added in
        # @@parser_priorities
        # So, to have always the same order, we sort by the order that the parsers
        # were registered if the priorities are the same.
        @parsers.index(parser_a) <=> @parsers.index(parser_b)
      end
    end

    # If there is one parser that is more likely to match, place it first
    if first_match = parsers_in_order_of_priority.find { |f| f.respond_to?(:likely_match?) && f.likely_match?(filename_hint) }
      parsers_in_order_of_priority.delete(first_match)
      parsers_in_order_of_priority.unshift(first_match)
    end

    parsers_in_order_of_priority
  end

  def self.string_to_lossy_utf8(str)
    replacement_char = [0xFFFD].pack('U')
    str.encode(Encoding::UTF_8, undef: :replace, replace: replacement_char)
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
