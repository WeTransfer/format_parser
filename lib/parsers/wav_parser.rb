class FormatParser::WAVParser
  include FormatParser::IOUtils

  WAV_MIME_TYPE = 'audio/x-wav'

  def likely_match?(filename)
    filename =~ /\.wav$/i
  end

  def call(io)
    # Read the RIFF header. Chunk descriptor should be RIFF, the size should
    # contain the size of the entire file in bytes minus 8 bytes for the
    # two fields not included in this count: chunk_id and size.
    chunk_id, _size, riff_type = safe_read(io, 12).unpack('a4la4')

    # The chunk_id and riff_type should be RIFF and WAVE respectively
    return unless chunk_id == 'RIFF' && riff_type == 'WAVE'

    # There are no restrictions upon the order of the chunks within a WAVE file,
    # with the exception that the Format chunk must precede the Data chunk.
    # The specification does not require the Format chunk to be the first chunk
    # after the RIFF header.
    # https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/WAVE.html
    fmt_processed = false
    fmt_data = {}
    loop do
      chunk_type, chunk_size = safe_read(io, 8).unpack('a4l')
      case chunk_type
      when 'fmt ' # watch out: the chunk ID of the format chunk ends with a space
        fmt_data = unpack_fmt_chunk(io, chunk_size)
        fmt_processed = true
      when 'data'
        return unless fmt_processed # the 'data' chunk cannot preceed the 'fmt ' chunk
        return file_info(fmt_data, chunk_size)
      else
        # Skip this chunk until a known chunk is encountered
        safe_skip(io, chunk_size)
      end
    end
  end

  def unpack_fmt_chunk(io, chunk_size)
    # The size of the fmt chunk is at least 16 bytes. If the format tag's value is not
    # 1 compression might be in use for storing the data
    # and the fmt chunk might contain extra fields appended to it.
    # The first 6 fields of the fmt tag are always:
    # * unsigned short     audio format
    # * unsigned short     channels
    # * unsigned long      samples per sec
    # * unsigned long      average bytes per sec
    # * unsigned short     block align
    # * unsigned short     bits per sample

    fmt_info = safe_read(io, 16).unpack('S_2I2S_2')
    safe_skip(io, chunk_size - 16) # skip the extra fields

    {
      audio_format: fmt_info[0],
      channels: fmt_info[1],
      sample_rate: fmt_info[2],
      byte_rate: fmt_info[3],
      block_align: fmt_info[4],
      bits_per_sample: fmt_info[5],
    }
  end

  def file_info(fmt_data, data_size)
    # NOTE: Each sample includes information for each channel
    sample_frames = data_size / (fmt_data[:channels] * fmt_data[:bits_per_sample] / 8) if fmt_data[:channels] > 0 && fmt_data[:bits_per_sample] > 0
    duration_in_seconds = data_size / fmt_data[:byte_rate].to_f if fmt_data[:byte_rate] > 0
    FormatParser::Audio.new(
      format: :wav,
      num_audio_channels: fmt_data[:channels],
      audio_sample_rate_hz: fmt_data[:sample_rate],
      media_duration_frames: sample_frames,
      media_duration_seconds: duration_in_seconds,
      content_type: WAV_MIME_TYPE,
    )
  end

  FormatParser.register_parser new, natures: :audio, formats: :wav
end
