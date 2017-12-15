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
    parsers = @parsers.map(&:new)
    parsers.each do |parser|
      if info = parser.information_from_io(io)
        return info
      end
    end

    raise "No parser could parse #{io.inspect}"
  end

  Dir.glob(__dir__ + '/parsers/*.rb').sort.each do |parser_file|
    require parser_file
  end
end
