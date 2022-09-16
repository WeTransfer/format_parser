class FormatParser::AACParser
  include FormatParser::IOUtils

  AAC_MIME_TYPE = 'audio/aac'
  AAC_ADTS_HEADER_BITS_PATTERN = 'AAAAAAAAAAAABCCDEEFFFFGHHHIJKLMMMMMMMMMMMMMOOOOOOOOOOOPPQQQQQQQQQQQQQQQQ'
  AAC_ADTS_PROTECTION_ABSENCE_INDEX = 15
  AAC_ADTS_HEADER_BYTES = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')
  MPEG4_AUDIO_OBJECT_TYPE_RANGE = 0..45
  MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE = 0..14
  MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH = { 0 => 96000, 1 => 88200, 2 => 64000, 3 => 48000, 4 => 44100, 5 => 32000, 6 => 24000, 7 => 22050, 8 => 16000, 9 => 12000, 10 => 11025, 11 => 8000, 12 => 7350 }

  def likely_match?(filename)
    filename =~ /\.aac?$/i
  end

  def call(raw_io)
    io = FormatParser::IOConstraint.new(raw_io)

    # header_bytes = io.read(9).unpack("H*").first
    header_bits = io.read(9).unpack('B*').first.split('')
    return unless validate_header(header_bits)

    file_info = FormatParser::Audio.new(
      title: nil,
      album: nil,
      artist: nil,
      format: :aac,
      num_audio_channels: get_number_of_audio_channels(header_bits),
      audio_sample_rate_hz: get_audio_sample_rate_hz(header_bits),
      media_duration_seconds: nil,
      media_duration_frames: nil,
      intrinsics: nil,
      content_type: AAC_MIME_TYPE
    )
  end

  private

  # Verifying whether the header conforms to ADTS standards
  # https://wiki.multimedia.cx/index.php/ADTS
  def validate_header(bits)
    bits.each_with_index do |bit, i|
      return false unless validate_header_bit(bit, i)
    end

    letters_to_validate_in_chunks = ['E', 'F', 'M', 'P']
    letters_to_validate_in_chunks.each do |letter|
      return false unless validate_header_chunk(bits, letter)
    end

    true
  end

  def validate_header_bit(bit_value, index)
    letter = AAC_ADTS_HEADER_BITS_PATTERN[index]
    case letter
    when 'A'
      # Syncword, all bits must be set to 1
      bit_value == '1'
    when 'B'
      # MPEG Version, set to 0 for MPEG-4 and 1 for MPEG-2
      true
    when 'C'
      # Layer, always set to 0
      bit_value == '0'
    when 'D'
      # Protection absence, set to 1 if there is no CRC and 0 if there is CRC
      true
    when 'G'
      # Private bit, guaranteed never to be used by MPEG, set to 0 when encoding, ignore when decoding
      true
    when 'H'
      # MPEG-4 Channel Configuration (in the case of 0, the channel configuration is sent via an in-band PCE (Program Config Element))
      true
    when 'I'
      # Originality, set to 1 to signal originality of the audio and 0 otherwise
      true
    when 'J'
      # Home, set to 1 to signal home usage of the audio and 0 otherwise
      true
    when 'K'
      # Copyright ID bit, the next bit of a centrally registered copyright identifier.
      # This is transmitted by sliding over the bit-string in LSB-first order and putting the current bit value
      # in this field and wrapping to start if reached end (circular buffer).
      true
    when 'L'
      # Copyright ID start, signals that this frame's Copyright ID bit is the first one by setting 1 and 0 otherwise
      true
    when 'O'
      # Buffer fullness, states the bit-reservoir per frame
      # skipping this one, as we don't care what the value is
      true
    when 'Q'
      # CRC check, if Protection absent is 0.
      # we don't actually care about the CRC
      true
    else
      true
    end
  end

  def validate_header_chunk(bits, letter)
    decimal_number = get_decimal_number_for_letter(bits, letter)

    case letter
    when 'E'
      # Profile, the MPEG-4 Audio Object Type minus 1
      MPEG4_AUDIO_OBJECT_TYPE_RANGE.include?(decimal_number + 1)
    when 'F'
      # MPEG-4 Sampling Frequency Index (15 is forbidden)
      MPEG4_AUDIO_SAMPLING_FREQUENCY_RANGE.include?(decimal_number)
    when 'M'
      # Frame length, length of the ADTS frame including headers and CRC check (protectionabsent == 1? 7: 9)
      # We expect this to be higher than the header length, but we won't impose any other restrictions
      header_length = bits[AAC_ADTS_PROTECTION_ABSENCE_INDEX] == 1 ? 7 : 9
      decimal_number > header_length
    when 'P'
      # Number of AAC frames (RDBs (Raw Data Blocks)) in ADTS frame minus 1. For maximum compatibility always use one AAC frame per ADTS frame.
      # Skipping this.
      true
    else
      true
    end
  end

  def get_decimal_number_for_letter(header_bits, letter)
    start_index = AAC_ADTS_HEADER_BITS_PATTERN.index(letter)
    end_index = AAC_ADTS_HEADER_BITS_PATTERN.rindex(letter)
    binary_chunk = header_bits[start_index..end_index]
    convert_binary_to_decimal(binary_chunk)
  end

  # Converts a binary number given as a array of characters representing bits, into a decimal number.
  def convert_binary_to_decimal(binary_number)
    integer = 0
    reversed_binary_array = binary_number.reverse
    reversed_binary_array.each_with_index { |num, index| integer += num.to_i * (2**index) }
    integer
  end

  def get_number_of_audio_channels(header_bits)
    mpeg4_channel_config = get_decimal_number_for_letter(header_bits, 'H')
    case
    when 1..6
      mpeg4_channel_config
    when 7
      8
    else
      nil
    end
  end

  def get_audio_sample_rate_hz(header_bits)
    mpeg4_sampling_frequency_index = get_decimal_number_for_letter(header_bits, 'F')
    if MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH.has_key?(mpeg4_sampling_frequency_index)
      return MPEG4_AUDIO_SAMPLING_FREQUENCY_HASH[mpeg4_sampling_frequency_index]
    end
    nil
  end

  FormatParser.register_parser new, natures: :audio, formats: :aac
end
