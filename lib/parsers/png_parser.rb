class FormatParser::PNGParser
  include FormatParser::IOUtils
  include FormatParser::DSL

  natures :image
  formats :png

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


  def chunk_length_and_type(io)
    safe_read(io, 8).unpack("Na4")
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    magic_bytes = safe_read(io, PNG_HEADER_BYTES.bytesize)
    return unless magic_bytes == PNG_HEADER_BYTES

    chunk_length, chunk_type = chunk_length_and_type(io)

    # For later: look at gAMA and iCCP chunks too. For now,
    # all we care about is the IHDR chunk, and it must have the
    # correct length as well.
    # IHDR _must_ come first, no exceptions. If it doesn't
    # we should not consider this a valid PNG.
    return unless chunk_type == "IHDR" && chunk_length == 13

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

    # Read the next chunk. If it turns out to be acTL (animation control)
    # we are dealing with an APNG.
    safe_skip(io, 4)

    # dry-validation won't let booleans be filled with nil so we have to set
    # has_animation to false by default
    has_animation = nil
    num_frames = nil
    loop_n_times = nil

    chunk_length, chunk_type = chunk_length_and_type(io)
    if chunk_length == 8 && chunk_type == 'acTL'
      # https://wiki.mozilla.org/APNG_Specification#.60acTL.60:_The_Animation_Control_Chunk
      # Unlike GIF, we do have the frame count that we can recover
      has_animation = true
      num_frames, loop_n_times = safe_read(io, 8).unpack('NN')
    end

    FormatParser::Image.new(
      format: :png,
      width_px: w,
      height_px: h,
      has_transparency: has_transparency,
      color_mode: color_mode,
      has_multiple_frames: has_animation,
      num_animation_or_video_frames: num_frames,
    )
  end

  FormatParser.register_parser_constructor self
end
