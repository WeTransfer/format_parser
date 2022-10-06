require_relative 'exif_parser'

class FormatParser::ARWParser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  # Standard TIFF headers
  MAGIC_LE = [0x49, 0x49, 0x2A, 0x0].pack('C4')
  MAGIC_BE = [0x4D, 0x4D, 0x0, 0x2A].pack('C4')
  HEADER_BYTES = [MAGIC_LE, MAGIC_BE]
  ARW_MIME_TYPE = 'image/x-sony-arw'

  def likely_match?(filename)
    filename =~ /\.arw$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless HEADER_BYTES.include?(safe_read(io, 4))
    exif_data = exif_from_tiff_io(io)

    return unless valid?(exif_data)

    w = exif_data.width || exif_data.pixel_x_dimension
    h = exif_data.height || exif_data.pixel_y_dimension

    FormatParser::Image.new(
      format: :arw,
      width_px: w,
      height_px: h,
      display_width_px: exif_data.rotated? ? h : w,
      display_height_px: exif_data.rotated? ? w : h,
      orientation: exif_data.orientation_sym,
      intrinsics: { exif: exif_data },
      content_type: ARW_MIME_TYPE,
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  def valid?(exif_data)
    # taken directly from tiff_parser.rb
    # Similar to how exiftool determines the image type as ARW, we are implementing a check here
    # https://github.com/exiftool/exiftool/blob/e969456372fbaf4b980fea8bb094d71033ac8bf7/lib/Image/ExifTool/Exif.pm#L929
    exif_data.compression == 6 && exif_data.new_subfile_type == 1 && exif_data.make&.start_with?('SONY')
  end

  FormatParser.register_parser new, natures: :image, formats: :arw
end
