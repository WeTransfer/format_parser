require 'ks'

class FormatParser::FLACParser
  MAGIC_BYTES = 4
  MAGIC_BYTE_STRING = 'fLaC'
  BLOCK_HEADER_BYTES = 4

  def bytestring_to_int(s)
    s.unpack('B*')[0].to_i(2)
  end

  def call(io)
    magic_bytes = io.read(MAGIC_BYTES)

    return unless magic_bytes == MAGIC_BYTE_STRING

    # Skip info we don't need
    io.seek(MAGIC_BYTES + BLOCK_HEADER_BYTES)

    minimum_block_size = bytestring_to_int(io.read(2))
    maximum_block_size = bytestring_to_int(io.read(2))
    minimum_frame_size = bytestring_to_int(io.read(3))
    maximum_frame_size = bytestring_to_int(io.read(3))

    # Audo info comes in irregularly sized (i.e. not 8-bit) chunks,
    # so read total as bitstring and parse seperately
    audio_info = io.read(8).unpack('B*')[0]

    # sample rate is 20 bits
    sample_rate = audio_info.slice!(0..19).to_i(2)

    # Number of channels is 3 bits
    # Header contains number of channels minus one, so add one
    num_channels = audio_info.slice!(0..2).to_i(2) + 1

    # Bits per sample is 5 bits
    # Header contains number of bits per sample minus one, so add one
    bits_per_sample = audio_info.slice!(0..4).to_i(2) + 1

    # Total samples is 36 bits
    total_samples = audio_info.slice!(0..35).to_i(2)

    duration = total_samples.to_f / sample_rate

    FormatParser::Audio.new(
      format: :flac,
      num_audio_channels: num_channels,
      audio_sample_rate_hz: sample_rate,
      media_duration_seconds: duration,
      media_duration_frames: total_samples,
      intrinsics: {
        bits_per_sample: bits_per_sample,
        minimum_frame_size: minimum_frame_size,
        maximum_frame_size: maximum_frame_size,
        minimum_block_size: minimum_block_size,
        maximum_block_size: maximum_block_size
      }
    )
  end

  FormatParser.register_parser self, natures: :audio, formats: :flac
end
