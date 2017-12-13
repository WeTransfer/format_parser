class FormatParser::PNGParser
  PNG_HEADER_BYTES = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')
  COLOR_TYPES = {
    0 => :grayscale,
    2 => :rgb,
    3 => :indexed,
    4 => :grayscale, # with alpha
    6 => :rgba,
  }
  TRANSPARENCY_PER_COLOR_TYPE = {
    0 => true,
    4 => true, # Grayscale with alpha
    6 => true,
  }
  
  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)
    magic_bytes = safe_read(io, PNG_HEADER_BYTES.bytesize)
    return unless magic_bytes == PNG_HEADER_BYTES

    # IHDR _must_ come first, no exceptions. If it doesn't
    # we might reconsider this later
    chunk_length = safe_read(io, 4).unpack("N").first
    chunk_type = safe_read(io, 4)

    # For later: look at gAMA and iCCP chunks too. For now,
    # all we care about is the IHDR chunk, and it must have the
    # correct length as well.
    if chunk_type == "IHDR" && chunk_length == 13
      chunk_data = safe_read(io, chunk_length)
      # Width:              4 bytes
      # Height:             4 bytes
      # Bit depth:          1 byte
      # Color type:         1 byte (0, 2, 3, 4, 6)
      # Compression method: 1 byte
      # Filter method:      1 byte
      # Interlace method:   1 byte
      w, h, bit_depth, color_type,
        compression_method, filter_method, interlace_method = chunk_data.unpack("N2C5")

      color_mode = COLOR_TYPES.fetch(color_type)
      has_transparency = TRANSPARENCY_PER_COLOR_TYPE[color_type]

      return FormatParser::FileInformation.image(
        file_type: :png,
        width_px: w,
        height_px: h,
        has_transparency: has_transparency,
        color_mode: color_mode,
      )
    end
  end
end
