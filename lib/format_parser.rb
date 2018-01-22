module FormatParser
  require_relative 'image'
  require_relative 'audio'
  require_relative 'document'
  require_relative 'video'
  require_relative 'io_utils'
  require_relative 'read_limiter'
  require_relative 'remote_io'
  require_relative 'io_constraint'
  require_relative 'care'
  require_relative 'parsers/dsl'

  PARSER_MUX = Mutex.new

  def self.register_parser_constructor(object_responding_to_new)
    PARSER_MUX.synchronize do
      @parsers ||= []
      @parsers << object_responding_to_new
      # Gathering natures and formats from parsers. An instance has to be created.
      parser = object_responding_to_new.new
      @natures ||= Set.new
      # NOTE: merge method for sets modify the instance.
      @natures.merge(parser.natures)
      @formats ||= Set.new
      @formats.merge(parser.formats)
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

  def self.parse(io, natures: @natures.to_a, formats: @formats.to_a, returns: :all)
    # If the cache is preconfigured do not apply an extra layer. It is going
    # to be preconfigured when using parse_http.
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)

    # How many results has the user asked for? Used to determinate whether an array
    # is returned or not.
    amount = case returns
             when :all
               @parsers.count
             when :one
               1
             else
               throw ArgumentError.new(':returns does not match any supported mode (:all, :one)')
             end

    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    results = parsers_for(natures, formats).map do |parser|
      # We need to rewind for each parser, anew
      io.seek(0)
      # Limit how many operations the parser can perform
      limited_io = ReadLimiter.new(io, max_bytes: 512 * 1024, max_reads: 64 * 1024, max_seeks: 64 * 1024)
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
    # Convert the results from a lazy enumerator to an array.
    results.to_a
  end

  def self.parsers_for(natures, formats)
    # returns lazy enumerator for only computing the minimum amount of work (see :returns keyword argument)
    @parsers.map(&:new).select do |parser|
      # Do a given parser contain any nature and/or format asked by the user?
      (natures & parser.natures).size > 0 && (formats & parser.formats).size > 0
    end.lazy
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
