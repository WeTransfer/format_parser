class FormatParser::TIFFParser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  MAGIC_LE = [0x49, 0x49, 0x2A, 0x0].pack('C4')
  MAGIC_BE = [0x4D, 0x4D, 0x0, 0x2A].pack('C4')
  HEADER_BYTES = [MAGIC_LE, MAGIC_BE]
  TIFF_MIME_TYPE = 'image/tiff'

  def likely_match?(filename)
    filename =~ /\.tiff?$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless HEADER_BYTES.include?(safe_read(io, 4))

    # Skip over the offset of the IFD,
    # EXIFR will re-read it anyway
    io.seek(io.pos + 2)
    return if cr2?(io)

    # The TIFF scanner in EXIFR is plenty good enough,
    # so why don't we use it? It does all the right skips
    # in all the right places.
    exif_data = exif_from_tiff_io(io)
    return unless exif_data

    # arw files are now handled in separate arw_parser
    return if arw?(exif_data)

    w = exif_data.width || exif_data.pixel_x_dimension
    h = exif_data.height || exif_data.pixel_y_dimension

    FormatParser::Image.new(
      format: :tif,
      width_px: w,
      height_px: h,
      display_width_px: exif_data.rotated? ? h : w,
      display_height_px: exif_data.rotated? ? w : h,
      orientation: exif_data.orientation_sym,
      intrinsics: {exif: exif_data},
      content_type: TIFF_MIME_TYPE,
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  def cr2?(io)
    io.seek(8)
    safe_read(io, 2) == 'CR'
  end

  # Similar to how exiftool determines the image type as ARW, we are implementing a check here
  # https://github.com/exiftool/exiftool/blob/e969456372fbaf4b980fea8bb094d71033ac8bf7/lib/Image/ExifTool/Exif.pm#L929
  # Change in version 1.7.0 to use start_with for make matching due to some sample images having a padded make
  def arw?(exif_data)
    exif_data.compression == 6 && exif_data.new_subfile_type == 1 && exif_data.make&.start_with?('SONY')
  end

  FormatParser.register_parser new, natures: :image, formats: :tif
end
