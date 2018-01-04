module FormatParser::MP3Parser::ID3V1
  PACKSPEC = [
    :tag, :a3,
    :song_name, :a30,
    :artist, :a30,
    :album, :a30,
    :year, :N1,
    :comment, :a30,
    :genre, :C,
  ]
  packspec_keys = PACKSPEC.select.with_index{|_, i| i.even? }

  class TagInformation < Struct.new(*packspec_keys)
  end

  def attempt_id3_v1_extraction(io)
    io.seek(io.size - 128)
    trailer_bytes  = io.read(128)
    unless trailer_bytes.byteslice(0, 3) == 'TAG'
      return nil
    end

    id3_v1 = parse_id3_v1(trailer_bytes)

    # If all of the resulting strings are empty this ID3v1 tag is invalid and
    # we should ignore it.
    strings_from_id3v1 = id3_v1.values.select{|e| e.is_a?(String) && e != 'TAG' }
    if strings_from_id3v1.all?(&:empty?)
      return nil
    end

    id3_v1
  end

  def parse_id3_v1(byte_str)
    keys, values = PACKSPEC.partition.with_index {|_, i| i.even? }
    unpacked_values = byte_str.unpack(values.join)
    unpacked_values.map! {|e| e.is_a?(String) ? trim_id3v1_string(e) : e }
    TagInformation.new(unpacked_values)
  end

  # Remove trailing whitespace and trailing nullbytes
  def trim_id3v1_string(str)
    str.tr("\x00".b, '').strip
  end

  extend self
end
