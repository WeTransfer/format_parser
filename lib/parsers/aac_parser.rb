require_relative 'aac_parser/adts_header_info'
class FormatParser::AACParser
  include FormatParser::IOUtils

  AAC_MIME_TYPE = 'audio/aac'

  # An ADTS header has the following format, when represented in bits:
  # AAAAAAAA AAAABCCD EEFFFFGH HHIJKLMM MMMMMMMM MMMOOOOO OOOOOOPP (QQQQQQQQ QQQQQQQQ)
  AAC_ADTS_HEADER_BITS_CHUNK_SIZES = [['A', 12], ['B', 1], ['C', 2], ['D', 1], ['E', 2], ['F', 4], ['G', 1], ['H', 3], ['I', 1], ['J', 1], ['K', 1], ['L', 1], ['M', 13], ['O', 11], ['P', 2], ['Q', 16]]
  MPEG4_AUDIO_OBJECT_TYPE_RANGE = 0..45
  MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE = 0..14

  def likely_match?(filename)
    filename =~ /\.aac?$/i
  end

  def call(raw_io)
    io = FormatParser::IOConstraint.new(raw_io)
    header_bits = io.read(9).unpack('B*').first.split('')

    header_info = parse_adts_header(header_bits)
    return if header_info.nil?

    file_info = FormatParser::Audio.new(
      title: nil,
      album: nil,
      artist: nil,
      format: :aac,
      num_audio_channels: header_info.number_of_audio_channels,
      audio_sample_rate_hz: header_info.mpeg4_sampling_frequency,
      media_duration_seconds: nil,
      media_duration_frames: nil,
      intrinsics: nil,
      content_type: AAC_MIME_TYPE
    )
  end

  private

  def parse_adts_header(header_bits)
    result = FormatParser::AdtsHeaderInfo.new

    AAC_ADTS_HEADER_BITS_CHUNK_SIZES.each do |letter_size|
      letter = letter_size[0]
      chunk_size = letter_size[1]
      chunk = header_bits.shift(chunk_size)
      decimal_number = convert_binary_to_decimal(chunk)

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
        # Profile, the MPEG-4 Audio Object Type minus 1
        return nil unless MPEG4_AUDIO_OBJECT_TYPE_RANGE.include?(decimal_number + 1)
        result.profile = decimal_number
      when 'F'
        # MPEG-4 Sampling Frequency Index (15 is forbidden)
        return nil unless MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE.include?(decimal_number)
        result.mpeg4_sampling_frequency_index = decimal_number
      when 'G'
        # Private bit, guaranteed never to be used by MPEG, set to 0 when encoding, ignore when decoding
      when 'H'
        # MPEG-4 Channel Configuration (in the case of 0, the channel configuration is sent via an in-band PCE (Program Config Element))
        result.mpeg4_channel_config = decimal_number
      when 'I'
        # Originality, set to 1 to signal originality of the audio and 0 otherwise
        result.originality = decimal_number == 1
      when 'J'
        # Home, set to 1 to signal home usage of the audio and 0 otherwise
        result.home_usage = decimal_number == 1
      when 'K'
        # Copyright ID bit, the next bit of a centrally registered copyright identifier.
        # This is transmitted by sliding over the bit-string in LSB-first order and putting the current bit value
        # in this field and wrapping to start if reached end (circular buffer).
      when 'L'
        # Copyright ID start, signals that this frame's Copyright ID bit is the first one by setting 1 and 0 otherwise
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
      when 'Q'
        # CRC check, if Protection absent is 0.
        # we don't actually care about the CRC
      end
    end

    result
  end

  def duration_in_seconds(file_size_bytes, adts_header_info)
    # audio file size = bit rate * duration of audio in seconds * number of channels
    # bit rate = bit depth * sample rate
    # audio file size = bit depth * sample rate * duration of audio * number of channels

    # bit rate = audio file size / (duration in seconds * number of channels)
    bit_depth = 16
    file_size_bits = file_size_bytes * 8
    # duration = file size / (frames per second * frame size)
    duration = file_size_bits / (adts_header_info.frame_rate * 60)

    # The duration of an MPEG audio frame is a function of the sampling rate and the number of samples per frame. The formula is:
    # frameTimeMs = (1000/SamplingRate) * SamplesPerFrame
    frame_time_ms = (1000 / adts_header_info.mpeg4_sampling_frequency) * adts_header_info.frame_length
  end

  # Converts a binary number given as a array of characters representing bits, into a decimal number.
  def convert_binary_to_decimal(binary_number)
    result = 0
    reversed_binary_array = binary_number.reverse
    reversed_binary_array.each_with_index { |num, index| result += num.to_i * (2**index) }
    result
  end

  FormatParser.register_parser new, natures: :audio, formats: :aac
end
