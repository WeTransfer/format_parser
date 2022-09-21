# This is a representation of the relevant information found in an Audio Data Transport Stream (ADTS) file header.
class FormatParser::AdtsHeaderInfo
  attr_accessor :mpeg_version, :layer, :protection_absence, :profile, :mpeg4_sampling_frequency_index,
                :mpeg4_channel_config, :originality, :home_usage, :frame_length, :buffer_fullness,
                :aac_frames_per_adts_frame

  # An ADTS header has the following format, when represented in bits:
  # AAAAAAAA AAAABCCD EEFFFFGH HHIJKLMM MMMMMMMM MMMOOOOO OOOOOOPP (QQQQQQQQ QQQQQQQQ)
  # The chunks represented by these letters have specific meanings, as described here:
  # https://wiki.multimedia.cx/index.php/ADTS

  AAC_ADTS_HEADER_BITS_CHUNK_SIZES = [
    ['A', 12], ['B', 1], ['C', 2], ['D', 1],
    ['E', 2], ['F', 4], ['G', 1], ['H', 3],
    ['I', 1], ['J', 1], ['K', 1], ['L', 1],
    ['M', 13], ['O', 11], ['P', 2], ['Q', 16]
  ]
  MPEG4_AUDIO_OBJECT_TYPE_RANGE = 0..45
  MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE = 0..14
  MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH = {
    0 => 96000, 1 => 88200, 2 => 64000,
    3 => 48000, 4 => 44100, 5 => 32000,
    6 => 24000, 7 => 22050, 8 => 16000,
    9 => 12000, 10 => 11025, 11 => 8000,
    12 => 7350, 13 => 'Reserved', 14 => 'Reserved'
  }
  AAC_PROFILE_DESCRIPTION_HASH = {
    0 => 'AAC_MAIN',
    1 => 'AAC_LC (Low Complexity)',
    2 => 'AAC_SSR (Scaleable Sampling Rate)',
    3 => 'AAC_LTP (Long Term Prediction)'
  }
  MPEG_VERSION_HASH = { 0 => 'MPEG-4', 1 => 'MPEG-2'}

  def mpeg4_sampling_frequency
    if !@mpeg4_sampling_frequency_index.nil? && MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH.key?(@mpeg4_sampling_frequency_index)
      return MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH[@mpeg4_sampling_frequency_index]
    end
    nil
  end

  def profile_description
    if !@profile.nil? && AAC_PROFILE_DESCRIPTION_HASH.key?(@profile)
      return AAC_PROFILE_DESCRIPTION_HASH[@profile]
    end
    nil
  end

  def mpeg_version_description
    if !@mpeg_version.nil? && MPEG_VERSION_HASH.key?(@mpeg_version)
      return MPEG_VERSION_HASH[@mpeg_version]
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

  def fixed_bitrate?
    # A buffer fullness value of 0x7FF (decimal: 2047) denotes a variable bitrate, for which buffer fullness isn't applicable
    @buffer_fullness != 2047
  end

  # The frame rate - i.e. frames per second
  def frame_rate
    # An AAC sample uncompresses to 1024 PCM samples
    mpeg4_sampling_frequency.to_f / 1024
  end

  # If the given bit array is a valid ADTS header, this method will parse it and return an instance of AdtsHeaderInfo.
  # Will return nil if the header does not match the ADTS specifications.
  def self.parse_adts_header(header_bits)
    result = FormatParser::AdtsHeaderInfo.new

    AAC_ADTS_HEADER_BITS_CHUNK_SIZES.each do |letter_size|
      letter = letter_size[0]
      chunk_size = letter_size[1]
      chunk = header_bits.shift(chunk_size)
      decimal_number = chunk.join.to_i(2)

      # Skipping data represented by the letters G, K, L, Q, as we are not interested in those values.
      case letter
      when 'A'
        # Syncword, all bits must be set to 1
        return nil unless chunk.all? { |bit| bit == '1' }
      when 'B'
        # MPEG Version, set to 0 for MPEG-4 and 1 for MPEG-2
        result.mpeg_version = decimal_number
      when 'C'
        # Layer, always set to 0
        return nil unless decimal_number == 0
      when 'D'
        # Protection absence, set to 1 if there is no CRC and 0 if there is CRC
        result.protection_absence = decimal_number == 1
      when 'E'
        # AAC Profile
        return nil unless MPEG4_AUDIO_OBJECT_TYPE_RANGE.include?(decimal_number + 1)
        result.profile = decimal_number
      when 'F'
        # MPEG-4 Sampling Frequency Index (15 is forbidden)
        return nil unless MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE.include?(decimal_number)
        result.mpeg4_sampling_frequency_index = decimal_number
      when 'H'
        # MPEG-4 Channel Configuration (in the case of 0, the channel configuration is sent via an in-band PCE (Program Config Element))
        result.mpeg4_channel_config = decimal_number
      when 'I'
        # Originality, set to 1 to signal originality of the audio and 0 otherwise
        result.originality = decimal_number == 1
      when 'J'
        # Home, set to 1 to signal home usage of the audio and 0 otherwise
        result.home_usage = decimal_number == 1
      when 'M'
        # Frame length, length of the ADTS frame including headers and CRC check (protectionabsent == 1? 7: 9)
        # We expect this to be higher than the header length, but we won't impose any other restrictions
        header_length = result.protection_absence ? 7 : 9
        return nil unless decimal_number > header_length
        result.frame_length = decimal_number
      when 'O'
        # Buffer fullness, states the bit-reservoir per frame.
        # It is merely an informative field with no clear use case defined in the specification.
        result.buffer_fullness = decimal_number
      when 'P'
        # Number of AAC frames (RDBs (Raw Data Blocks)) in ADTS frame minus 1. For maximum compatibility always use one AAC frame per ADTS frame.
        result.aac_frames_per_adts_frame = decimal_number + 1
      end
    end

    result
  end
end
