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
    if0_offset = parse_sequence_to_int tiff_header[4..7]

    parse_ifd_0(io, if0_offset)
    set_orientation(io, if0_offset)

    exif_offset = parse_ifd(io, if0_offset, EXIF_OFFSET_TAG)

    set_photo_info(io, exif_offset[0])

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
      intrinsics: intrinsics
    )
  end

  private

  def parse_ifd(io, offset, searched_tag)
    io.seek(offset)
    entries_count = parse_sequence_to_int safe_read(io, 2)
    entries_count.times do
      entry = safe_read(io, 12)
      tag_id = parse_sequence_to_int entry[0..1]
      type = parse_sequence_to_int entry[2..3]
      length = parse_sequence_to_int entry[4..7]
      value = parse_sequence_to_int entry[8..11]
      return [value, length, type] if tag_id == searched_tag
    end
    nil
  end

  def parse_sequence_to_int(sequence)
    sequence.reverse.unpack('H*').join.hex
  end

  def parse_new_model(io, offset, length)
    io.seek(offset)
    items = safe_read(io, length)
    @width = parse_sequence_to_int items[8..9]
    @height = parse_sequence_to_int items[10..11]
  end

  def parse_old_model(io, offset, length)
    io.seek(offset)
    items = safe_read(io, length)
    @width = parse_sequence_to_int items[4..5]
    @height = parse_sequence_to_int items[6..7]
  end

  def parse_ifd_0(io, offset)
    resolution_offset = parse_ifd(io, offset, PREVIEW_RESOLUTION_TAG)
    resolution_data = read_data(io, resolution_offset[0], resolution_offset[1] * 8, resolution_offset[2])
    @resolution = resolution_data[0] / resolution_data[1]

    @preview_offset = parse_ifd(io, offset, PREVIEW_IMAGE_OFFSET_TAG).first
    @preview_byte_count = parse_ifd(io, offset, PREVIEW_IMAGE_BYTE_COUNT_TAG).first

    model_offset = parse_ifd(io, offset, CAMERA_MODEL_TAG)
    @model = read_data(io, model_offset[0], model_offset[1], model_offset[2])

    shoot_date_offset = parse_ifd(io, offset, SHOOT_DATE_TAG)
    @shoot_date = read_data(io, shoot_date_offset[0], shoot_date_offset[1], shoot_date_offset[2])
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

  def set_photo_info(io, offset)
    # Type for exposure, aperture and resolution is unsigned rational
    # Unsigned rational = 2x unsigned long (4 bytes)
    exposure_offset = parse_ifd(io, offset, EXPOSURE_TAG)
    exposure_data = read_data(io, exposure_offset[0], exposure_offset[1] * 8, exposure_offset[2])
    @exposure = "#{exposure_data[0]}/#{exposure_data[1]}"

    aperture_offset = parse_ifd(io, offset, APERTURE_TAG)
    aperture_data = read_data(io, aperture_offset[0], aperture_offset[1] * 8, aperture_offset[2])
    @aperture = "f#{aperture_data[0] / aperture_data[1].to_f}"
  end

  def read_data(io, offset, length, type)
    io.seek(offset)
    data = io.read(length)
    case type
    when 5
      n = parse_sequence_to_int data[0..3]
      d = parse_sequence_to_int data[4..7]
      [n, d]
    else
      data
    end
  end

  def intrinsics
    {
      camera_model: @model,
      shoot_date: @shoot_date,
      exposure: @exposure,
      aperture: @aperture,
      resolution: @resolution,
      preview_offset: @preview_offset,
      preview_length: @preview_byte_count
    }
  end

  FormatParser.register_parser self, natures: :image, formats: :cr2
end