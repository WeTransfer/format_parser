require 'set'

module FormatParser
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

  PARSER_MUX = Mutex.new
  MAX_BYTES_READ_PER_PARSER = 1024 * 1024 * 2

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

  def self.deregister_parser(callable_or_responding_to_new)
    # Used only in tests
    PARSER_MUX.synchronize do
      (@parsers || []).delete(callable_or_responding_to_new)
      (@parsers_per_nature || {}).values.map { |e| e.delete(callable_or_responding_to_new) }
      (@parsers_per_format || {}).values.map { |e| e.delete(callable_or_responding_to_new) }
    end
  end

  def self.parse_http(url, **kwargs)
    parse(RemoteIO.new(url), **kwargs)
  end

  # Return all by default
  def self.parse(io, natures: @parsers_per_nature.keys, formats: @parsers_per_format.keys, results: :first)
    # We need to apply various limits so that parsers do not over-read, do not cause too many HTTP
    # requests to be dispatched and so on. These should be _balanced_ with one another- for example,
    # we cannot tell a parser that it is limited to reading 1024 bytes while at the same time
    # limiting the size of the cache pages it may slurp in to less than that amount, since
    # it can quickly become frustrating. The limits configurator computes these limits
    # for us, in a fairly balanced way, based on one setting.
    limit_config = FormatParser::ReadLimitsConfig.new(MAX_BYTES_READ_PER_PARSER)

    # Limit the number of cached _pages_ we may fetch. This allows us to limit the number
    # of page faults (page cache misses) a parser may incur
    read_limiter_under_cache = FormatParser::ReadLimiter.new(io, max_reads: limit_config.max_pagefaults_per_parser)

    # Then configure a layer of caching on top of that
    cached_io = Care::IOWrapper.new(read_limiter_under_cache, page_size: limit_config.cache_page_size)

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
    limited_io = ReadLimiter.new(cached_io, max_bytes: limit_config.max_read_bytes_per_parser, max_reads: limit_config.max_reads_per_parser, max_seeks: limit_config.max_seeks_per_parser)

    results = parsers.lazy.map do |parser|
      # Reset all the read limits, per parser
      limited_io.reset_limits!
      read_limiter_under_cache.reset_limits!

      # We need to rewind for each parser, anew
      limited_io.seek(0)

      begin
        parser.call(limited_io)
      rescue IOUtils::InvalidRead
        # There was not enough data for this parser to work on,
        # and it triggered an error
      rescue IOUtils::MalformedFile
        # Unexpected input was encountered during the parsing of
        # a file. This might indicate either a malicious or a
        # corruped file.
      rescue ReadLimiter::BudgetExceeded
        # The parser tried to read too much - most likely the file structure
        # caused the parser to go off-track. Strictly speaking we should log this
        # and examine the file more closely.
        # Or the parser caused too many cache pages to be fetched, which likely means we should not allow
        # it to continue
      end
    end.reject(&:nil?).take(amount)

    return results.first if amount == 1

    # Convert the results from a lazy enumerator to an Array.
    results.to_a
  end

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

  def self.instantiate_parser(callable_or_responding_to_new)
    if callable_or_responding_to_new.respond_to?(:call)
      callable_or_responding_to_new
    elsif callable_or_responding_to_new.respond_to?(:new)
      callable_or_responding_to_new.new
    else
      raise ArgumentError, 'A parser should be either a class with an instance method #call or a Proc'
    end
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
