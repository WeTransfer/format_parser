class FormatParser::PSDParser
  include FormatParser::IOUtils

  PSD_HEADER = [0x38, 0x42, 0x50, 0x53]

  def self.likely_match?(filename)
    filename =~ /\.psd$/i # Maybe also PSB at some point
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    magic_bytes = safe_read(io, 4).unpack('C4')

    return unless magic_bytes == PSD_HEADER

    # We can be reasonably certain this is a PSD so we grab the height
    # and width bytes
    w, h = safe_read(io, 22).unpack('x10N2')
    FormatParser::Image.new(
      format: :psd,
      width_px: w,
      height_px: h,
    )
  end

  FormatParser.register_parser self, natures: :image, formats: :psd
end
