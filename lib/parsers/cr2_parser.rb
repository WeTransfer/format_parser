class FormatParser::CR2Parser
  include FormatParser::IOUtils

  # Variables
  PREVIEW_WIDTH_TAG = 0x0100
  PREVIEW_HEIGHT_TAG = 0x0101
  PREVIEW_ORIENTATION_TAG = 0x0112
  PREVIEW_RESOLUTION_TAG = 0x011a
  PREVIEW_IMAGE_OFFSET_TAG = 0x0111
  PREVIEW_IMAGE_BYTE_COUNT_TAG = 0x0117
  ORIENTATIONS = [
    nil,
    :TopLeft,
    :TopRight,
    :BottomRight,
    :BottomLeft,
    :LeftTop,
    :RightTop,
    :RightBottom,
    :LeftBottom,
  ]

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    tiff_header = safe_read(io, 8)

    # Offset to IFD #0 where the preview image data is located
    # For more information about CR2 format,
    # see http://lclevy.free.fr/cr2/
    # and https://github.com/lclevy/libcraw2/blob/master/docs/cr2_poster.pdf
    if0_offset = tiff_header[4..7].reverse.bytes.collect{ |c| c.to_s(16) }.join.hex

    cr2_check_bytes = safe_read(io, 2)

    # Check whether it's a CR2 file
    return unless cr2_check_bytes == 'CR'
    set_data(io, if0_offset)

    FormatParser::Image.new(
      format: :cr2,
      width_px: @width,
      height_px: @height,
      orientation: ORIENTATIONS[@orientation],
      image_orientation: @orientation,
      resolution: @resolution
    )
  end

  private

  def parse_ifd(io, offset, searched_tag)
    io.seek(offset)
    entries_count = to_hex safe_read(io, 2)
    entries_count.times do |index|
      entry = safe_read(io, 12)
      tag_id = to_hex(entry[0..1])
      value = to_hex(entry[8..11])
      return value if tag_id == searched_tag
    end
  end

  def to_hex(sequence)
    sequence.bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
  end

  def set_data(io, offset)
    @width = parse_ifd(io, offset, PREVIEW_WIDTH_TAG)
    @height = parse_ifd(io, offset, PREVIEW_HEIGHT_TAG)
    @orientation = parse_ifd(io, offset, PREVIEW_ORIENTATION_TAG)
    @resolution = parse_ifd(io, offset, PREVIEW_RESOLUTION_TAG)
  end

  FormatParser.register_parser self, natures: :image, formats: :cr2
end

