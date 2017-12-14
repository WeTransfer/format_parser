require 'ostruct'

module FormatParser
  require_relative 'file_information'
  require_relative 'io_utils'
  require_relative 'remote_io'
  require_relative 'care'
  require_relative 'parsers/png_parser'
  require_relative 'parsers/jpeg_parser'
  require_relative 'parsers/psd_parser'
  require_relative 'parsers/tiff_parser'
  require_relative 'parsers/dpx_parser'
  require_relative 'parsers/gif_parser'

  def self.parse_http(url)
    parse(RemoteIO.new(url))
  end

  def self.parse(io)
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)
    parsers = [PNGParser.new, JPEGParser.new, TIFFParser.new, PSDParser.new, DPXParser.new, GIFParser.new]
    parsers.each do |parser|
      if info = parser.information_from_io(io)
        return info
      end
    end

    raise "No parser could parse #{io.inspect}"
  end
end
