module FormatParser
  module Parsers
    class ImageParser
      PARSERS = [
        FormatParser::Parsers::Image::DPXParser,
        FormatParser::Parsers::Image::GIFParser,
        FormatParser::Parsers::Image::JPEGParser,
        FormatParser::Parsers::Image::PNGParser,
        FormatParser::Parsers::Image::PSDParser,
        FormatParser::Parsers::Image::TIFFParser
      ].freeze

      def call(file)
        PARSERS.map(&:new).inject(nil) do |_, parser|
          result = parser.call(file)
          break result unless result.nil?
        end
      end
    end
  end
end
