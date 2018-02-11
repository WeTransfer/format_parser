module FormatParser
  require 'set'
  require_relative 'image'
  require_relative 'audio'
  require_relative 'document'
  require_relative 'video'
  require_relative 'io_utils'
  require_relative 'read_limiter'
  require_relative 'remote_io'
  require_relative 'io_constraint'
  require_relative 'care'

  PARSER_MUX = Mutex.new
  MAX_BYTES = 512 * 1024
  MAX_READS = 64 * 1024
  MAX_SEEKS = 64 * 1024

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
    remote_io = RemoteIO.new(url)
    cached_io = Care::IOWrapper.new(remote_io)

    # Prefetch the first page, since it is very likely to be touched
    # by all parsers anyway. Additionally, when using RemoteIO we need
    # to explicitly obtain the size of the resource, which is only available
    # after having performed at least one successful GET - at least on S3
    cached_io.read(1)
    cached_io.seek(0)

    parse(cached_io, **kwargs)
  end

  # Return all by default
  def self.parse(io, natures: @parsers_per_nature.keys, formats: @parsers_per_format.keys, results: :first)
    # If the cache is preconfigured do not apply an extra layer. It is going
    # to be preconfigured when using parse_http.
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)

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

    results = parsers.lazy.map do |parser|
      # We need to rewind for each parser, anew
      io.seek(0)
      # Limit how many operations the parser can perform
      limited_io = ReadLimiter.new(io, max_bytes: MAX_BYTES, max_reads: MAX_READS, max_seeks: MAX_SEEKS)
      begin
        parser.call(limited_io)
      rescue IOUtils::InvalidRead
        # There was not enough data for this parser to work on,
        # and it triggered an error
      rescue ReadLimiter::BudgetExceeded
        # The parser tried to read too much - most likely the file structure
        # caused the parser to go off-track. Strictly speaking we should log this
        # and examine the file more closely.
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
