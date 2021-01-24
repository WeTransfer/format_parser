require_relative 'exif_parser'

class FormatParser::CR2Parser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  TIFF_HEADER = [0x49, 0x49, 0x2a, 0x00]
  CR2_HEADER  = [0x43, 0x52, 0x02, 0x00]
  CR2_MIME_TYPE = 'image/x-canon-cr2'

  def likely_match?(filename)
    filename =~ /\.cr2$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    tiff_header = safe_read(io, 8)

    # Check whether it's a CR2 file
    tiff_bytes = tiff_header[0..3].bytes
    magic_bytes = safe_read(io, 4).unpack('C4')

    return if !magic_bytes.eql?(CR2_HEADER) || !tiff_bytes.eql?(TIFF_HEADER)

    # The TIFF scanner in EXIFR is plenty good enough,
    # so why don't we use it? It does all the right skips
    # in all the right places.
    exif_data = exif_from_tiff_io(io)
    return unless exif_data

    w = exif_data.image_width
    h = exif_data.image_length

    FormatParser::Image.new(
      format: :cr2,
      width_px: w,
      height_px: h,
      display_width_px: exif_data.rotated? ? h : w,
      display_height_px: exif_data.rotated? ? w : h,
      orientation: exif_data.orientation_sym,
      intrinsics: {exif: exif_data},
      content_type: CR2_MIME_TYPE,
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  FormatParser.register_parser new, natures: :image, formats: :cr2
end
