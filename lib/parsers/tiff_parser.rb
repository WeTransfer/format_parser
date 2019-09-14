class FormatParser::TIFFParser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  MAGIC_LE = [0x49, 0x49, 0x2A, 0x0].pack('C4')
  MAGIC_BE = [0x4D, 0x4D, 0x0, 0x2A].pack('C4')

  def likely_match?(filename)
    filename =~ /\.tiff?$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless [MAGIC_LE, MAGIC_BE].include?(safe_read(io, 4))
    io.seek(io.pos + 2) # Skip over the offset of the IFD, EXIFR will re-read it anyway
    return if cr2?(io)

    # The TIFF scanner in EXIFR is plenty good enough,
    # so why don't we use it? It does all the right skips
    # in all the right places.
    exif_data = exif_from_tiff_io(io)
    return unless exif_data

    w = exif_data.image_width
    h = exif_data.image_length

    FormatParser::Image.new(
      format: :tif,
      width_px: w,
      height_px: h,
      display_width_px: exif_data.rotated? ? h : w,
      display_height_px: exif_data.rotated? ? w : h,
      orientation: exif_data.orientation_sym,
      intrinsics: {exif: exif_data},
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  def cr2?(io)
    io.seek(8)
    safe_read(io, 2) == 'CR'
  end

  FormatParser.register_parser new, natures: :image, formats: :tif
end
