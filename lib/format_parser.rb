require 'set'

# A pretty nimble module for parsing file metadata using partial reads. Contains all the
# top-level methods of the library.
module FormatParser
  require_relative 'format_parser/version'
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
  require_relative 'care'

  # Is used to manage access to the shared array of parser constructors, which might
  # potentially be mutated from different threads. The mutex won't be hit too often
  # since it only locks when adding/removing parsers.
  PARSER_MUX = Mutex.new
  MAX_BYTES_READ_PER_PARSER = 1024 * 1024 * 2

  # Register a parser object to be used to perform file format detection. Each parser FormatParser
  # provides out of the box registers itself using this method.
  #
  # @param callable_or_responding_to_new[#call, #new] an object that either responds to #new or to #call
  # @param formats[Array<Symbol>] file formats that the parser provides
  # @param natures[Array<Symbol>] file natures that the parser provides
  # @return void
  def self.register_parser(callable_or_responding_to_new, formats:, natures:)
    parser_provided_formats = Array(formats)
    parser_provided_natures = Array(natures)
    PARSER_MUX.synchronize do
      @parsers ||= Set.new
      @parsers << callable_or_responding_to_new
      @parsers_per_nature ||= {}
      parser_provided_natures.each do |provided_nature|
        @parsers_per_nature[provided_nature] ||= Set.new
        @parsers_per_nature[provided_nature] << callable_or_responding_to_new
      end
      @parsers_per_format ||= {}
      parser_provided_formats.each do |provided_format|
        @parsers_per_format[provided_format] ||= Set.new
        @parsers_per_format[provided_format] << callable_or_responding_to_new
      end
    end
  end

  # Deregister a parser object (makes FormatParser forget this parser existed). Is mostly used in
  # tests, but can also be used to forcibly disable some formats completely.
  #
  # @param callable_or_responding_to_new[#call, #new] an object that either responds to #new or to #call
  # @return void
  def self.deregister_parser(callable_or_responding_to_new)
    # Used only in tests
    PARSER_MUX.synchronize do
      (@parsers || []).delete(callable_or_responding_to_new)
      (@parsers_per_nature || {}).values.map { |e| e.delete(callable_or_responding_to_new) }
      (@parsers_per_format || {}).values.map { |e| e.delete(callable_or_responding_to_new) }
    end
  end

  # Parses the resource at the given `url` and returns the results as if it were any IO
  # given to `.parse`. The accepted keyword arguments are the same as the ones for `parse`.
  #
  # @param url[String, URI] the HTTP(S) URL to request the object from using Faraday and `Range:` requests
  # @param kwargs the keyword arguments to be delegated to `.parse`
  # @see {.parse}
  def self.parse_http(url, **kwargs)
    parse(RemoteIO.new(url), **kwargs)
  end

  # Parses the file at the given `path` and returns the results as if it were any IO
  # given to `.parse`. The accepted keyword arguments are the same as the ones for `parse`.
  #
  # @param path[String] the path to the file to parse on the local filesystem
  # @param kwargs the keyword arguments to be delegated to `.parse`
  # @see {.parse}
  def self.parse_file_at(path, **kwargs)
    File.open(path, 'rb') do |io|
      parse(io, **kwargs)
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
  # @param results[:first, :all, Integer] one of the values defining how many results to return if parsing
  #   is ambiguous. The default is `:first` which returns the first matching result. Other
  #   possible values are `:all` to get all possible results and an Integer to return
  #   at most N results.
  # @param limits_config[ReadLimitsConfig] the configuration object for various read/cache limits. The default
  #   one should be good for most cases.
  # @return [Array<Result>, Result, nil] either an Array of results, a single parsing result or `nil`if
  #   no useful metadata could be recovered from the file
  def self.parse(io, natures: @parsers_per_nature.keys, formats: @parsers_per_format.keys, results: :first, limits_config: default_limits_config)
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
    parsers = parsers_for(natures, formats)

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

    if results.empty?
      Measurometer.increment_counter('format_parser.unknown_files', 1)
    end

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
    parser_name_for_instrumentation = parser.class.to_s.split('::').last
    Measurometer.instrument('format_parser.parser.%s' % parser_name_for_instrumentation) do
      parser.call(limited_io).tap do |result|
        if result
          Measurometer.increment_counter('format_parser.detected_natures.%s' % result.nature, 1)
          Measurometer.increment_counter('format_parser.detected_formats.%s' % result.format, 1)
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
  # @return [Array<#call>] an array of callable parsers
  # @raise ArgumentError when there are no parsers satisfying the constraint
  def self.parsers_for(desired_natures, desired_formats)
    assemble_parser_set = ->(hash_of_sets, keys_of_interest) {
      hash_of_sets.values_at(*keys_of_interest).compact.inject(&:+) || Set.new
    }

    fitting_by_natures = assemble_parser_set[@parsers_per_nature, desired_natures]
    fitting_by_formats = assemble_parser_set[@parsers_per_format, desired_formats]
    factories = fitting_by_natures & fitting_by_formats

    if factories.empty?
      raise ArgumentError, "No parsers provide both natures #{desired_natures.inspect} and formats #{desired_formats.inspect}"
    end

    factories.map { |callable_or_class| instantiate_parser(callable_or_class) }
  end

  # Instantiates a parser object (an object that responds to `#call`) from a given class
  # or returns the parameter as is if it is callable by itself - i.e. if it is a Proc
  #
  # @param callable_or_responding_to_new[#call, #new] a callable or a Class/Module
  # @return [#call] a parser that can be called with an IO-ish argument
  def self.instantiate_parser(callable_or_responding_to_new)
    if callable_or_responding_to_new.respond_to?(:call)
      callable_or_responding_to_new
    elsif callable_or_responding_to_new.respond_to?(:new)
      callable_or_responding_to_new.new
    else
      raise ArgumentError, 'A parser should be either a class with an instance method #call or a Proc'
    end
  end

  def self.string_to_lossy_utf8(str)
    replacement_char = [0xFFFD].pack('U')
    str.encode(Encoding::UTF_8, undef: :replace, replace: replacement_char)
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
  # The Measurometer latches itself onto existing classes, so load it after
  # we have loaded all the parsers
  require_relative 'measurometer'
end
