require_relative 'exif_parser'

class FormatParser::RW2Parser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  PANASONIC_RAW_MIMETYPE = 'image/x-panasonic-raw'
  RW2_MAGIC_BYTES = [0x49, 0x49, 0x55, 0x0, 0x18, 0x0, 0x0, 0x0].pack('C8')
  RAW_RWL_MAGIC_BYTES = [0x49, 0x49, 0x55, 0x0, 0x08, 0x0, 0x0, 0x0].pack('C8')
  MAGIC_BYTES = [RW2_MAGIC_BYTES, RAW_RWL_MAGIC_BYTES]
  BORDER_TAG_IDS = {
    top: 4,
    left: 5,
    bottom: 6,
    right: 7
  }

  def likely_match?(filename)
    /\.(rw2|raw|rwl)$/i.match?(filename)
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    return unless matches_rw2_definition?

    @buf.seek(0)
    exif = exif_from_tiff_io(@buf)
    return unless exif

    # RW2 doesn't use the standard EXIF width and height tags (🤷🏻). We can compute them from the sensor
    # top/bottom/left/right border tags. See https://exiftool.org/TagNames/PanasonicRaw.html for more.
    left_sensor_border = sensor_border(exif, :left)
    right_sensor_border = sensor_border(exif, :right)
    w = right_sensor_border - left_sensor_border if left_sensor_border && right_sensor_border

    top_sensor_border = sensor_border(exif, :top)
    bottom_sensor_border = sensor_border(exif, :bottom)
    h = bottom_sensor_border - top_sensor_border if top_sensor_border && bottom_sensor_border

    FormatParser::Image.new(
      format: :rw2,
      width_px: w,
      height_px: h,
      display_width_px: exif.rotated? ? h : w,
      display_height_px: exif.rotated? ? w : h,
      orientation: exif.orientation_sym,
      intrinsics: { exif: exif },
      content_type: PANASONIC_RAW_MIMETYPE,
    )
  rescue EXIFR::MalformedTIFF
    nil
  end

  private

  def matches_rw2_definition?
    MAGIC_BYTES.include?(read_bytes(8))
  end

  def sensor_border(exif, border)
    exif[0]&.raw_fields&.[](BORDER_TAG_IDS[border])&.[](0)
  end

  FormatParser.register_parser new, natures: [:image], formats: [:rw2]
end
