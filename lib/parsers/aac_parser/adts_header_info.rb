# This is a representation of the relevant information found in an Audio Data Transport Stream (ADTS) file header.
class FormatParser::AdtsHeaderInfo
  attr_accessor :mpeg_version, :layer, :protection_absence, :profile, :mpeg4_sampling_frequency_index,
                :mpeg4_channel_config, :originality, :home_usage, :frame_length, :buffer_fullness,
                :aac_frames_per_adts_frame
  
  MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH = {
    0 => 96000, 1 => 88200, 2 => 64000, 3 => 48000, 4 => 44100, 5 => 32000, 6 => 24000,
    7 => 22050, 8 => 16000, 9 => 12000, 10 => 11025, 11 => 8000, 12 => 7350,
    13 => 'Reserved', 14 => 'Reserved'
  }

  def mpeg4_sampling_frequency
    if !@mpeg4_sampling_frequency_index.nil? && MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH.has_key?(@mpeg4_sampling_frequency_index)
      return MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH[@mpeg4_sampling_frequency_index]
    end
    nil
  end

  def number_of_audio_channels
    case @mpeg4_channel_config
    when 1..6
      @mpeg4_channel_config
    when 7
      8
    else
      nil
    end
  end

  def has_fixed_bitrate?
    # A buffer fullness value of 0x7FF (decimal: 2047) denotes a variable bitrate, for which buffer fullness isn't applicable
    @buffer_fullness != 2047
  end

  # The frame rate - i.e. frames per second
  def frame_rate
    # An AAC sample uncompresses to 1024 PCM samples
    mpeg4_sampling_frequency.to_f / 1024
  end
end
