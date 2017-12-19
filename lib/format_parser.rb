require 'thread'
require 'magic_bytes'

module FormatParser
  require_relative 'file_information'
  require_relative 'io_utils'
  require_relative 'remote_io'
  require_relative 'care'

  PARSER_MUX = Mutex.new

  def self.register_parser_constructor(object_responding_to_new, filetype)
    PARSER_MUX.synchronize do
      @parsers ||= {}
      @parsers[filetype.to_sym] = object_responding_to_new
    end
  end

  def self.parse_http(url)
    parse(RemoteIO.new(url))
  end

  def self.parse(io)
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)
    io.seek(0)
    filetype = parse_magic_bytes(io)
    parser = @parsers[filetype]
    if parser.nil?
      return nil
    end
    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    parser = parser.new
    io.seek(0) # Make sure we're rewound
    info = parser.information_from_io(io)
    return info if info
    rescue FormatParser::IOUtils::InvalidRead
    # There was not enough data for this parser to work on,
    # and it triggered an error
    nil # Nothing matched
  end

  def self.parse_magic_bytes(io)
    filetype = MagicBytes.read_and_detect(io)
    filetype.ext.to_sym
  rescue
    nil
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
