class FormatParser::TIFFParser
  include FormatParser::IOUtils
  include FormatParser::ExifFlipDimensions

  MAGIC_LE = [0x49, 0x49, 0x2A, 0x0].pack('C4')
  MAGIC_BE = [0x4D, 0x4D, 0x0, 0x2A].pack('C4')

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless [MAGIC_LE, MAGIC_BE].include?(safe_read(io, 4))
    io.seek(io.pos + 2) # Skip over the offset of the IFD, EXIFR will re-read it anyway
    return if cr2?(io)

    # The TIFF scanner in EXIFR is plenty good enough,
    # so why don't we use it? It does all the right skips
    # in all the right places.
    scanner = FormatParser::EXIFParser.new(io)
    scanner.scan_image_tiff
    return unless scanner.exif_data

    w = scanner.exif_data.image_width
    h = scanner.exif_data.image_length
    FormatParser::Image.new(
      format: :tif,
      width_px: w, 
      height_px: h,
      display_width_px: rotated?(scanner.orientation) ? h : w,
      display_height_px: rotated?(scanner.orientation) ? w : h,
      orientation: scanner.orientation
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  def cr2?(io)
    io.seek(8)
    safe_read(io, 2) == 'CR'
  end

  FormatParser.register_parser self, natures: :image, formats: :tif
end
