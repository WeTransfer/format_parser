require 'ks'

module FormatParser
  FileInformation = Ks.strict(:width_px, :height_px)
  require_relative 'io_utils'
  require_relative 'care'
  require_relative 'parsers/png_parser'
  require_relative 'parsers/jpeg_parser'
  require_relative 'parsers/dpx_parser'

  def self.parse(io)
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)
    parsers = [PNGParser.new, JPEGParser.new, DPXParser.new]
    parsers.each do |parser|
      if info = parser.information_from_io(io)
        return info
      end
    end
  
    raise "No parser could parse #{io.inspect}"
  end
end

if __FILE__ == $0
#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test.png', 'rb')
#  file_info = FormatParser::PNGParser.new.information_from_io(fi)
#  $stderr.puts file_info.inspect

  fi = File.open(__dir__ + '/../spec/fixtures/test4.jpg', 'rb')
  file_info = FormatParser::JPEGParser.new.information_from_io(fi)
#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test1.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test2.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test3.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)
end