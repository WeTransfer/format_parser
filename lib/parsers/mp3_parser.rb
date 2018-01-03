class FormatParser::MP3Parser
  include FormatParser::IOUtils

  def information_from_io(io)
    # Read the last 128 bytes which might contain ID3v1
    id3_v1 = attempt_id3_v1_extraction(io)
    raise id3_v1.inspect
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

  FormatParser.register_parser_constructor self
end
