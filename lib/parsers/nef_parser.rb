class FormatParser::NEFParser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  MAGIC_LE = [0x49, 0x49, 0x2A, 0x0].pack('C4')
  MAGIC_BE = [0x4D, 0x4D, 0x0, 0x2A].pack('C4')
  HEADER_BYTES = [MAGIC_LE, MAGIC_BE]
  NEF_MIME_TYPE = 'image/x-nikon-nef'

  SUBFILE_TYPE_FULL_RESOLUTION = 0
  SUBFILE_TYPE_REDUCED_RESOLUTION = 1

  def likely_match?(filename)
    filename =~ /\.nef$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless HEADER_BYTES.include?(safe_read(io, 4))

    # Because of how NEF files organize their IFDs and subIFDs, we need to dive into the subIFDs
    # to get the actual image dimensions instead of the preview's
    should_parse_sub_ifds = true

    exif_data = exif_from_tiff_io(io, should_parse_sub_ifds)

    return unless valid?(exif_data)

    full_resolution_data = get_full_resolution_ifd(exif_data)

    w = full_resolution_data.image_width || exif_data.width || exif_data.pixel_x_dimension
    h = full_resolution_data.image_length || exif_data.height || exif_data.pixel_y_dimension

    FormatParser::Image.new(
      format: :nef,
      width_px: w,
      height_px: h,
      display_width_px: exif_data.rotated? ? h : w,
      display_height_px: exif_data.rotated? ? w : h,
      orientation: exif_data.orientation_sym,
      intrinsics: { exif: exif_data },
      content_type: NEF_MIME_TYPE,
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  def valid?(exif_data)
    # NEF files should hold subIFDs and have "NIKON" or "NIKON CORPORATION" as maker
    has_sub_ifds_data = !exif_data&.sub_ifds_data&.keys.empty?
    has_sub_ifds_data && exif_data&.make&.start_with?('NIKON')
  end

  # Investigates data from all subIFDs and find the one holding the full-resolution image
  def get_full_resolution_ifd(exif_data)
    # Most of the time, NEF files have 2 subIFDs:
    # First one: Thumbnail (Reduce resolution)
    # Second one: Full resolution
    # While this is true in most situations, there are exceptions,
    # so we can't rely in this order alone.

    exif_data.sub_ifds_data.each do |_ifd_offset, ifd_data|
      return ifd_data if ifd_data.new_subfile_type == SUBFILE_TYPE_FULL_RESOLUTION
    end
  end

  FormatParser.register_parser new, natures: :image, formats: :nef, priority: 4
end
