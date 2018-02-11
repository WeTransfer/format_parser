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
  end
  def parse_ifd(io, offset)
    io.seek(offset)
    entries_count = safe_read(io, 2).reverse.bytes.collect{ |c| c.to_s(16) }.join.hex
    entries_count.times do |index|
      entry = safe_read(io, 12)
      id = entry[0..1].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      type = entry[2..3].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      count = entry[4..7].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      value = entry[8..11].bytes.reverse.map { |b| sprintf("%02X",b) }.join
    end
  end
end
