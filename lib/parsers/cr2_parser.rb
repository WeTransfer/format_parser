class FormatParser::CR2Parser
  include FormatParser::IOUtils

  TIFF_HEADER = [0x49, 0x49, 0x2a, 0x00]
  CR2_HEADER  = [0x43, 0x52, 0x02, 0x00]

  PREVIEW_ORIENTATION_TAG = 0x0112
  PREVIEW_RESOLUTION_TAG = 0x011a
  PREVIEW_IMAGE_OFFSET_TAG = 0x0111
  PREVIEW_IMAGE_BYTE_COUNT_TAG = 0x0117
  EXIF_OFFSET_TAG = 0x8769
  MAKERNOTE_OFFSET_TAG = 0x927c
  AFINFO_TAG = 0x0012
  AF2INFO_TAG = 0x0026
  CAMERA_MODEL_TAG = 0x0110
  SHOOT_DATE_TAG = 0x0132
  EXPOSURE_TAG = 0x829a
  APERTURE_TAG = 0x829d

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    tiff_header = safe_read(io, 8)

    # Check whether it's a CR2 file
    tiff_bytes = tiff_header[0..3].bytes
    magic_bytes = safe_read(io, 4).unpack('C4')

    return if !magic_bytes.eql?(CR2_HEADER) || !tiff_bytes.eql?(TIFF_HEADER)

    # Offset to IFD #0 where the preview image data is located
    # For more information about CR2 format,
    # see http://lclevy.free.fr/cr2/
    # and https://github.com/lclevy/libcraw2/blob/master/docs/cr2_poster.pdf
    if0_offset = to_hex(tiff_header[4..7])

    set_orientation(io, if0_offset)
    set_resolution(io, if0_offset)
    set_preview(io, if0_offset)
    set_model_and_date(io, if0_offset)

    # Check CanonAFInfo or CanonAFInfo2 tags in maker notes for width & height
    exif_offset = parse_ifd(io, if0_offset, EXIF_OFFSET_TAG)
    makernote_offset = parse_ifd(io, exif_offset[0], MAKERNOTE_OFFSET_TAG)
    af_info = parse_ifd(io, makernote_offset[0], AF2INFO_TAG)

    # Old Canon models have CanonAFInfo tags
    # Newer models have CanonAFInfo2 tags instead
    # See https://sno.phy.queensu.ca/~phil/exiftool/TagNames/Canon.html
    if !af_info.nil?
      parse_new_model(io, af_info[0], af_info[1])
    else
      af_info = parse_ifd(io, makernote_offset[0], AFINFO_TAG)
      parse_old_model(io, af_info[0], af_info[1])
    end

    FormatParser::Image.new(
      format: :cr2,
      width_px: @width,
      height_px: @height,
      orientation: @orientation,
      image_orientation: @image_orientation,
      resolution: @resolution,
      preview: parse_preview_image(io)
    )
  end

  private

  def parse_ifd(io, offset, searched_tag)
    io.seek(offset)
    entries_count = to_hex safe_read(io, 2)
    entries_count.times do
      entry = safe_read(io, 12)
      tag_id = to_hex(entry[0..1])
      length = to_hex(entry[4..7])
      value = to_hex(entry[8..11])
      return [value, length] if tag_id == searched_tag
    end
    nil
  end

  def to_hex(sequence)
    sequence.reverse.unpack('H*').join.hex
  end

  def parse_new_model(io, offset, length)
    io.seek(offset)
    items = safe_read(io, length)
    @width = to_hex(items[8..9])
    @height = to_hex(items[10..11])
  end

  def parse_old_model(io, offset, length)
    io.seek(offset)
    items = safe_read(io, length)
    @width = to_hex(items[4..5])
    @height = to_hex(items[6..7])
  end

  def set_orientation(io, offset)
    orient = parse_ifd(io, offset, PREVIEW_ORIENTATION_TAG).first
    # Some old models do not have orientation info in TIFF headers
    return if orient > 8
    # EXIF orientation is an one based index
    # http://sylvana.net/jpegcrop/exif_orientation.html
    @orientation = FormatParser::EXIFParser::ORIENTATIONS[orient - 1]
    @image_orientation = orient
  end

  def set_resolution(io, offset)
    @resolution = parse_ifd(io, offset, PREVIEW_RESOLUTION_TAG).first
  end

  def set_preview(io, offset)
    @preview_offset = parse_ifd(io, offset, PREVIEW_IMAGE_OFFSET_TAG).first
    @preview_byte_count = parse_ifd(io, offset, PREVIEW_IMAGE_BYTE_COUNT_TAG).first
  end

  def parse_preview_image(io)
    return if @preview_byte_count > FormatParser::MAX_BYTES || @preview_offset > FormatParser::MAX_SEEKS
    io.seek(@preview_offset)
    safe_read(io, @preview_byte_count)
  end

  def set_model_and_date(io, offset)
    model_offset = parse_ifd(io, offset, CAMERA_MODEL_TAG)
    @model = read_data(io, model_offset[0], model_offset[1])

    shoot_date_offset = parse_ifd(io, offset, SHOOT_DATE_TAG)
    @shoot_date = read_data(io, shoot_date_offset[0], shoot_date_offset[1])
  end

  def set_photo_info(io, offset)
    # Type for exposure and aperture is unsigned rationnal
    # Unsigned rational = 2x unsigned long (4 bytes)
    exposure = parse_ifd(io, offset, EXPOSURE_TAG)
    exposure_data = read_data(io, exposure[0], exposure[1]*8)
    n = to_hex(exposure_data[0..3])
    d = to_hex(exposure_data[4..7])
    @exposure = "#{n}/#{d}"

    aperture = parse_ifd(io, offset, APERTURE_TAG)
    aperture_data = read_data(io, aperture[0], aperture[1]*8)
    n = to_hex(aperture_data[0..3])
    d = to_hex(aperture_data[4..7])
    @aperture = "f#{n/d}"
  end

  def read_data(io, offset, length)
    io.seek(offset)
    io.read(length)
  end

  FormatParser.register_parser self, natures: :image, formats: :cr2
end
