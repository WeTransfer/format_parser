module FormatParser::Parsers
  module Image
    class PSDParser
      PSD_HEADER = [0x38, 0x42, 0x50, 0x53].freeze
      include FormatParser::IOUtils

      def call(io)
        magic_bytes = safe_read(io, 4).unpack('C4')

        return unless magic_bytes == PSD_HEADER

        # We can be reasonably certain this is a PSD so we grab the height
        # and width bytes
        w, h = safe_read(io, 22).unpack('x10N2')

        # NOTE: Is a PSD really an image? It could fall into the Document category,
        # alongside with .pdf, .doc, .pages... and all that.
        FormatParser::Image.new(
          format: :psd,
          width_px: w,
          height_px: h
        )
      end
    end
  end
end
