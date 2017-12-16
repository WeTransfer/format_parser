require 'thread'

module FormatParser
  require_relative 'file_information'
  require_relative 'io_utils'
  require_relative 'remote_io'
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

    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    parsers = @parsers.map(&:new)

    parsers.each do |parser|
      io.seek(0) # We need to rewind for each parser, anew
      begin
        if info = parser.information_from_io(io)
          return info
        end
      rescue FormatParser::IOUtils::InvalidRead
        # There was not enough data for this parser to work on,
        # and it triggered an error
      end
    end
    nil # Nothing matched
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
