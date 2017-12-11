class FormatParser::TIFFParser
  LITTLE_ENDIAN_TIFF_HEADER_BYTES = [0x49, 0x49, 0x2A, 0x0]
  BIG_ENDIAN_TIFF_HEADER_BYTES = [0x4D, 0x4D, 0x0, 0x2A]
  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)
    magic_bytes = safe_read(io, 4).unpack("C4")
    return unless magic_bytes == LITTLE_ENDIAN_TIFF_HEADER_BYTES || magic_bytes == BIG_ENDIAN_TIFF_HEADER_BYTES

    # # This is mostly likely a PNG, so let's read some chunks
    # loop do
    #   chunk_length = safe_read(io, 4).unpack("N").first
    #   chunk_type = safe_read(io, 4)
    #   if chunk_type == "IHDR"
    #     chunk_data = safe_read(io, chunk_length)
    #     # Width:              4 bytes
    #     # Height:             4 bytes
    #     # Bit depth:          1 byte
    #     # Color type:         1 byte (0, 2, 3, 4, 6)
    #     # Compression method: 1 byte
    #     # Filter method:      1 byte
    #     # Interlace method:   1 byte
    #     w, h, depth, color_type, compression, filter, interlace = chunk_data.unpack("N2C5")
    return FormatParser::FileInformation.new(width_px: w, height_px: h)
  end
end
