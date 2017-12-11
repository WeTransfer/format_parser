class FormatParser::PNGParser
  PNG_HEADER_BYTES = [137, 80, 78, 71, 13, 10, 26, 10]
  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)
    magic_bytes = safe_read(io, 8).unpack("C8")

    return unless magic_bytes == PNG_HEADER_BYTES

    # This is mostly likely a PNG, so let's read some chunks
    loop do
      chunk_length = safe_read(io, 4).unpack("N").first
      chunk_type = safe_read(io, 4)
      if chunk_type == "IHDR"
        chunk_data = safe_read(io, chunk_length)
        # Width:              4 bytes
        # Height:             4 bytes
        # Bit depth:          1 byte
        # Color type:         1 byte (0, 2, 3, 4, 6)
        # Compression method: 1 byte
        # Filter method:      1 byte
        # Interlace method:   1 byte
        w, h = chunk_data.unpack("N2C5")
        return FileInformation.new(width_px: w, height_px: h)
      end
    end
  end
end
