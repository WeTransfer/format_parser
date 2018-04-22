class FormatParser::TIFFParser
  include FormatParser::IOUtils

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

    FormatParser::Image.new(
      format: :tif,
      width_px: scanner.exif_data.image_width,
      height_px: scanner.exif_data.image_length,
      # might be nil if EXIF metadata wasn't found
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
