module FormatParser::MP3Parser::ID3V2
  def attempt_id3_v2_extraction(io)
    io.seek(0) # Only support header ID3v2
    header_bytes = io.read(10)
    return nil unless header_bytes

    header = parse_id3_v2_header(header_bytes)
    return nil unless header[:tag] == 'ID3'
    return nil unless header[:size] > 0

    header_tag_payload = io.read(header[:size])
    header_tag_payload = StringIO.new(header_tag_payload)

    return nil unless header_tag_payload.size == header[:size]

    frames = []
    loop do
      break if header_tag_payload.eof?
      frame = parse_id3_v2_frame(header_tag_payload)
      # Some files include padding, which is there so that when you edit ID3v2
      # you do not have to overwrite the entire file - you can use this padding to
      # add some more tags or to grow the existing ones. In practice if we hit
      # something with a type of "0x00000000" we have entered the padding zone and
      # there is no point in parsing further
      if frame[:id] == "\x00\x00\x00\x00".b
        break
      else
        frames << frame
      end
    end
    frames
  end

  def parse_id3_v2_header(byte_str)
    packspec = [
      :tag, :a3,
      :version, :a2,
      :flags, :C1,
      :size, :a4,
    ]
    keys, values = packspec.partition.with_index {|_, i| i.even? }
    unpacked_values = byte_str.unpack(values.join)
    header_data = Hash[keys.zip(unpacked_values)]
    
    header_data[:version] = header_data[:version].unpack('C2')
    header_data[:size] = decode_syncsafe_int(header_data[:size])

    header_data
  end

  def parse_id3_v2_frame(io)
    id, syncsafe_size, flags = io.read(10).unpack('a4a4a2')
    size = decode_syncsafe_int(syncsafe_size)
    content = io.read(size)
    # It might so happen in sutations of terrible invalidity that we end up
    # with less data than advertised by the syncsafe size. We will just truck on.
    {id: id, size: size, flags: flags, content: content}
  end

  # ID3v2 uses "unsynchronized integers", which are unsigned integers smeared
  # over multiple bytes in such a manner that the first bit is always 0 (unset).
  # This is done so that ID3v2 incompatible decoders will not by accident see
  # the 0xFF0xFF0xFF0xFF sequence anywhere that can be mistaken for the MPEG frame
  # synchronisation header. Effectively it is a 7 bit big-endian unsigned integer
  # encoding.
  #
  # 8 bit 255 (0xFF) encoded in this mannner takes 16 bits instead,
  # and looks like this: `0b00000001 01111111`. Note how it avoids having
  # the first bit of the second byte be 1.
  # This method decodes an unsigned integer packed in this fashion
  def decode_syncsafe_int(bytes)
    size = 0
    j = 0
    i = bytes.bytesize - 1
    while i >= 0
      size += 128**i * (bytes.getbyte(j) & 0x7f)
      j += 1
      i -= 1
    end
    size
  end

  extend self
end
