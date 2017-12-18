class FormatParser::AIFFParser
  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)
    form_chunk_type, chunk_size = safe_read(io, 8).unpack('a4N')

    return unless form_chunk_type == "FORM" && chunk_size > 4

    fmt_chunk_type = safe_read(io, 4)
    return unless fmt_chunk_type == "AIFF"

    # The ID is always COMM. The chunkSize field is the number of bytes in the
    # chunk. This does not include the 8 bytes used by ID and Size fields. For
    # the Common Chunk, chunkSize should always 18 since there are no fields of
    # variable length (but to maintain compatibility with possible future
    # extensions, if the chunkSize is > 18, you should always treat those extra
    # bytes as pad bytes).
    comm_chunk_type, comm_chunk_size = safe_read(io, 8).unpack('a4N')
    return unless comm_chunk_type == "COMM" && comm_chunk_size == 18

    # Parse the COMM chunk
    channels, sample_frames, sample_size, sample_rate_extended = safe_read(io, 2 + 4 + 2 + 10).unpack('nNna10')
    sample_rate = unpack_extended_float(sample_rate_extended)
    bytes_per_sample = (sample_size - 1) / 8 + 1

    return unless sample_frames > 0

    # The sample rate is in Hz, so to get duration in seconds, as a float...
    duration_in_seconds = sample_frames / sample_rate
    return unless duration_in_seconds > 0

    FormatParser::FileInformation.new(
      file_nature: :audio,
      num_audio_channels: channels,
      audio_sample_rate_hz: sample_rate.to_i,
      media_duration_frames: sample_frames,
      media_duration_seconds: duration_in_seconds,
    )
  end
 
  def unpack_extended_float(ten_bytes_string)
    extended = ten_bytes_string.unpack('B80')[0]

    sign = extended[0, 1]
    exponent = extended[1, 15].to_i(2) - ((1 << 14) - 1)
    fraction = extended[16, 64].to_i(2)
  
    ((sign == '1') ? -1.0 : 1.0) * (fraction.to_f / ((1 << 63) - 1)) * (2 ** exponent)
  end

  FormatParser.register_parser_constructor self
end
