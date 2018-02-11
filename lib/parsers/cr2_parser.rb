class FormatParser::CR2Parser
  include FormatParser::IOUtils

  # Variables
  PREVIEW_WIDTH_TAG = 0x0100
  PREVIEW_HEIGHT_TAG = 0x0101
  PREVIEW_ORIENTATION_TAG = 0x0112
  PREVIEW_RESOLUTION_TAG = 0x011a
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
    if0_offset = tiff_header[4..7].reverse.bytes.collect{ |c| c.to_s(16) }.join.hex

    cr2_check_bytes = safe_read(io, 2)

    # Check whether it's a CR2 file
    return unless cr2_check_bytes == 'CR'
    parse_ifd(io, if0_offset)

    FormatParser::Image.new(
      format: :cr2,
      width_px: @width,
      height_px: @height,
      orientation: ORIENTATIONS[@orientation]
    )
  end

  def parse_ifd(io, offset)
    io.seek(offset)
    entries_count = to_hex safe_read(io, 2)
    entries_count.times do |index|
      entry = safe_read(io, 12)
      tag_id = to_hex(entry[0..1])
      value = to_hex(entry[8..11])
      set_data(tag_id, value)
    end
  end

  def to_hex(sequence)
    sequence.bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
  end

  def set_data(tag, value)
    case tag
    when PREVIEW_WIDTH_TAG
      @width = value
    when PREVIEW_HEIGHT_TAG
      @height = value
    when PREVIEW_ORIENTATION_TAG
      @orientation = value
    when PREVIEW_RESOLUTION_TAG
      @resolution = value
    end
  end
end

