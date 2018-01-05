require 'thread'

module FormatParser
  require_relative 'file_information'
  require_relative 'io_utils'
  require_relative 'read_limiter'
  require_relative 'remote_io'
  require_relative 'io_constraint'
  require_relative 'care'

  PARSER_MUX = Mutex.new

  def self.register_parser_constructor(object_responding_to_new)
    PARSER_MUX.synchronize do
      @parsers ||= []
      @parsers << object_responding_to_new
    end
  end

  def self.parse_http(url)
    parse(RemoteIO.new(url))
  end

  def self.parse(io)
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)

    # Prefetch the first page, since it is very likely to be touched
    # by all parsers anyway. Additionally, when using RemoteIO we need
    # to obtain the size of the resource, which is only available
    # after having performed the first GET - at least on S3
    io.read(1); io.seek(0)

    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    parsers = @parsers.map(&:new)

    parsers.each do |parser|
      # We need to rewind for each parser, anew
      io.seek(0)
      # Limit how many operations the parser can perform
      limited_io = ReadLimiter.new(io, max_bytes: 512*1024, max_reads: 64*1024, max_seeks: 64*1024)
      begin
        if info = parser.information_from_io(limited_io)
          return info
        end
      rescue IOUtils::InvalidRead
        # There was not enough data for this parser to work on,
        # and it triggered an error
      rescue ReadLimiter::BudgetExceeded
        # The parser tried to read too much - most likely the file structure
        # caused the parser to go off-track. Strictly speaking we should log this
        # and examine the file more closely.
      end
    end
    nil # Nothing matched
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
