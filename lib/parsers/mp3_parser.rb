class FormatParser::MP3Parser
  include FormatParser::IOUtils

  def information_from_io(io)
    # Read the last 128 bytes which might contain ID3v1
    id3_v1 = attempt_id3_v1_extraction(io)
    id3_v2 = attempt_id3_v2_extraction(io)
    raise id3_v2.inspect
  end

  def attempt_id3_v1_extraction(io)
    io.seek(io.size - 128)
    trailer_bytes  = io.read(128)
    id3_v1 = if trailer_bytes.byteslice(0, 3) == 'TAG'
      parse_id3_v1(trailer_bytes)
    else
      nil
    end

    # If all of the resulting strings are empty this ID3v1 tag is invalid and
    # we should ignore it.
    strings_from_id3v1 = id3_v1.values.select{|e| e.is_a?(String) && e != 'TAG' }
    if strings_from_id3v1.all?(&:empty?)
      id3_v1 = nil
    end
  end

  def attempt_id3_v2_extraction(io)
    io.seek(0) # Only support header ID3v2
    header_bytes = io.read(10)
    header = parse_id3_v2_header(header_bytes)
  end

  def parse_id3_v2_header(byte_str)
    packspec = [
      :tag, :a3,
      :version, :a2,
      :flags, :a1,
      :size, :a4,
    ]
    keys, values = packspec.partition.with_index {|_, i| i.even? }
    unpacked_values = byte_str.unpack(values.join)
    unpacked_values.map! {|e| e.is_a?(String) ? trim_id3v1_string(e) : e }
    header_data = Hash[keys.zip(unpacked_values)]
    header_data[:size] = int_from_32bits_unsynchronized(header_data[:size])
  end

  def parse_id3_v1(byte_str)
    packspec = [
      :tag, :a3,
      :song_name, :a30,
      :artist, :a30,
      :album, :a30,
      :year, :N1,
      :comment, :a30,
      :genre, :C,
    ]
    keys, values = packspec.partition.with_index {|_, i| i.even? }
    unpacked_values = byte_str.unpack(values.join)
    unpacked_values.map! {|e| e.is_a?(String) ? trim_id3v1_string(e) : e }
    Hash[keys.zip(unpacked_values)]
  end

  def trim_id3v1_string(str)
    # Remove trailing whitespace and trailing nullbytes
    str.tr("\x00".b, '').strip
  end

  def int_from_16bits_unsynchronized(two_byte_str)
    # 8 bit 255 (0xFF) encoded an an unsynchronized integer takes 16 bits instead,
    # and looks like this: 0b0000000101111111
    # to ensure no byte ever has all of it's bits set. It "smears" out the MSB
    # into the adjacent byte.
  end
  
  def int_from_32bits_unsynchronized(four_byte_str)
  end

  def encode_syncsafe_int(int)
    mask = 0x7F
    while mask <= 0x7FFFFFFF
      out = int & ~mask
      out = out << 1
      out |= (int & mask)
      mask = ((mask + 1) << 8) - 1
      int = out
    end
    out
  end

  def decode_syncsafe_int(synchsafe_int)
    out = 0
    mask = 0x7F000000
    while mask > 0
      out = out >> 1
      out |= (synchsafe_int & mask)
      mask = mask >> 8
    end
    out
  end

  FormatParser.register_parser_constructor self
end
