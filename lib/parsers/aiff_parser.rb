class FormatParser::AIFFParser
  include FormatParser::IOUtils
  include FormatParser::DSL

  # Known chunk types we can omit when parsing,
  # grossly lifted from http://www.muratnkonar.com/aiff/
  KNOWN_CHUNKS = [
    'COMT',
    'INST',
    'MARK',
    'SKIP',
    'SSND',
    'MIDI',
    'AESD',
    'APPL',
    'NAME',
    'AUTH',
    '(c) ', # yes it is a thing
    'ANNO',
  ]

  natures :audio
  formats :aiff

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    form_chunk_type, chunk_size = safe_read(io, 8).unpack('a4N')
    return unless form_chunk_type == 'FORM' && chunk_size > 4

    fmt_chunk_type = safe_read(io, 4)

    return unless fmt_chunk_type == 'AIFF'

    # There might be COMT chunks, for example in Logic exports
    loop do
      chunk_type, chunk_size = safe_read(io, 8).unpack('a4N')
      case chunk_type
      when 'COMM'
        # The ID is always COMM. The chunkSize field is the number of bytes in the
        # chunk. This does not include the 8 bytes used by ID and Size fields. For
        # the Common Chunk, chunkSize should always 18 since there are no fields of
        # variable length (but to maintain compatibility with possible future
        # extensions, if the chunkSize is > 18, you should always treat those extra
        # bytes as pad bytes).
        return unpack_comm_chunk(io)
      when *KNOWN_CHUNKS
        # We continue looping only if we encountered something that looks like
        # a valid AIFF chunk type - skip the size and continue
        safe_skip(io, chunk_size)
        next
      else # This most likely not an AIFF
        return
      end
    end
  end

  def unpack_comm_chunk(io)
    # Parse the COMM chunk
    channels, sample_frames, sample_size, sample_rate_extended = safe_read(io, 2 + 4 + 2 + 10).unpack('nNna10')
    sample_rate = unpack_extended_float(sample_rate_extended)
    bytes_per_sample = (sample_size - 1) / 8 + 1

    return unless sample_frames > 0

    # The sample rate is in Hz, so to get duration in seconds, as a float...
    duration_in_seconds = sample_frames / sample_rate
    return unless duration_in_seconds > 0

    FormatParser::Audio.new(
      format: :aiff,
      num_audio_channels: channels,
      audio_sample_rate_hz: sample_rate.to_i,
      media_duration_frames: sample_frames,
      media_duration_seconds: duration_in_seconds
    )
  end

  def unpack_extended_float(ten_bytes_string)
    extended = ten_bytes_string.unpack('B80')[0]

    sign = extended[0, 1]
    exponent = extended[1, 15].to_i(2) - ((1 << 14) - 1)
    fraction = extended[16, 64].to_i(2)

    (sign == '1' ? -1.0 : 1.0) * (fraction.to_f / ((1 << 63) - 1)) * (2**exponent)
  end

  FormatParser.register_parser_constructor self
end
