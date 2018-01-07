class FormatParser::WAVParser
  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)

    # Read the RIFF header. Chunk descriptor should be RIFF, the size should 
    # contain the size of the entire file in bytes minus 8 bytes for the 
    # two fields not included in this count: chunk_id and size.
    chunk_id, size, riff_type = safe_read(io, 12).unpack('a4la4')

    # The chunk_id and riff_type should be RIFF and WAVE respectively
    return unless chunk_id == 'RIFF' && riff_type == 'WAVE'

    # There are no restrictions upon the order of the chunks within a WAVE file,
    # with the exception that the Format chunk must precede the Data chunk.
    # The specification does not require the Format chunk to be the first chunk
    # after the RIFF header.
    # http://soundfile.sapp.org/doc/WaveFormat/
    loop do
      chunk_type, chunk_size = safe_read(io, 8).unpack('a4l')
      case chunk_type
      when 'fmt '
        return unpack_fmt_chunk(io, chunk_size)
      when 'data' # the 'data' chunk cannot preceed the 'fmt ' chunk
        return
      else # Skip processing the chunk until an 'fmt ' chunk is encountered
        safe_skip(io, chunk_size)
        next
      end
    end
  end

  def unpack_fmt_chunk(io, chunk_size)
    # The size of the fmt chunk is at least 16 bytes. If the format tag's value is not
    # 1 compression might be in use for storing the data
    # and the fmt chunk might contain extra fields appended to it.
    # The last 4 fields of the fmt tag are always:
    # * unsigned short     channels
    # * unsigned long      samples per sec
    # * unsigned long      average bytes per sec
    # * unsigned short     block align
    # * unsigned short     bits per sample

    audio_format, channels, sample_rate, byte_rate, block_align,
    bits_per_sample = safe_read(io, 16).unpack('S_2I2S_2')

    # channels, sample_rate and bits_per_sample should all be > 0 in order
    # to calculate media_duration_frames and media_duration_seconds
    return unless channels > 0 and sample_rate > 0 and bits_per_sample > 0
    
    safe_skip(io, chunk_size - 16) # skip the extra fields if any
    data_bytes = data_size(io)

    return if data_bytes.nil?

    sample_frames = data_bytes / (channels * bits_per_sample / 8)
    duration_in_seconds = sample_frames / sample_rate.to_f

    FormatParser::FileInformation.new(
      file_nature: :audio,
      file_type: :wav,
      num_audio_channels: channels,
      audio_sample_rate_hz: sample_rate,
      media_duration_frames: sample_frames,
      media_duration_seconds: duration_in_seconds,
    )
  end

  def data_size(io)
    # Read the size of the 'data' chunk
    loop do
      chunk_type, chunk_size = safe_read(io, 8).unpack('a4l')
      if chunk_type == 'data'
        return chunk_size
      else
        safe_skip(io, chunk_size)
      end
    end
  end

  FormatParser.register_parser_constructor self
end
