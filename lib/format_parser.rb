require 'ks'

module FormatParser
  FileInformation = Ks.strict(:width_px, :height_px)
  require_relative 'io_utils'
  require_relative 'care'
  require_relative 'parsers/png_parser'
  require_relative 'parsers/jpeg_parser'

  def self.parse(io) # #seek(n_bytes, IO::SEEK_SET), #read(n_bytes_or_nil)
    parsers = [PNGParser, JPEGParser]
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

  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test4.jpg', 'rb')
  file_info = FormatParser::JPEGParser.new.information_from_io(fi)
#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test1.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test2.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test3.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)
end