module FormatParser::MP3Parser::ID3Extraction
  ID3V1_TAG_SIZE_BYTES = 128
  ID3V2_TAG_VERSIONS = ["\x43\x00".b, "\x03\x00".b, "\x02\x00".b]
  MAX_SIZE_FOR_ID3V2 = 1 * 1024 * 1024

  extend FormatParser::IOUtils

  def attempt_id3_v1_extraction(io)
    return if io.size < ID3V1_TAG_SIZE_BYTES # Won't fit the ID3v1 regardless

    io.seek(io.size - 128)
    trailer_bytes = io.read(128)

    return unless trailer_bytes && trailer_bytes.bytesize == ID3V1_TAG_SIZE_BYTES
    return unless trailer_bytes.byteslice(0, 3) == 'TAG'

    buf = StringIO.new(trailer_bytes)
    swallow_exceptions { ID3Tag.read(buf, :v1) }
  end

  def attempt_id3_v2_extraction(io)
    io.seek(0) # Only support header ID3v2
    header = parse_id3_v2_header(io)
    return unless header[:tag] == 'ID3' && header[:size] > 0
    return unless ID3V2_TAG_VERSIONS.include?(header[:version])

    id3_tag_size = io.pos + header[:size]

    # Here we got to pay attention. The tag size encoded in
    # the ID3 header is a 4-byte unsigned int. Meaning it
    # can hold values up to 256 MB. We do not want to read
    # that much since we are pulling that data into memory -
    # and it would also make the parser easily exploitable.
    # We will set a "hard" limit beyound which we will simply
    # refuse to read those tags at all.
    if id3_tag_size > MAX_SIZE_FOR_ID3V2
      io.seek(id3_tag_size) # For reading the frames
      return
    end

    io.seek(0)
    blob = safe_read(io, id3_tag_size)

    swallow_exceptions { ID3Tag.read(StringIO.new(blob), :v2) }
  rescue FormatParser::IOUtils::InvalidRead
    nil
  end

  def read_and_unpack_packspec(io, **packspec)
    sizes = {'a' => 1, 'N' => 4}
    n = packspec.values.map { |e| sizes.fetch(e[0]) * e[1].to_i }.inject(&:+)
    byte_str = safe_read(io, n)

    unpacked_values = byte_str.unpack(packspec.values.join)
    Hash[packspec.keys.zip(unpacked_values)]
  end

  def parse_id3_v2_header(io)
    fields = {tag: :a3, version: :a2, flags: :a1, syncsafe_size: :N1}
    header_data = read_and_unpack_packspec(io, **fields)
    header_data[:size] = ID3Tag::SynchsafeInteger.decode(header_data.delete(:syncsafe_size))
    header_data
  end

  # We swallow exceptions from ID3Tag primarily because it does not have
  # a single wrapping error class we could capture. We also do not touch our original
  # IO object when working with ID3Tag
  def swallow_exceptions
    yield
  rescue => e
    warn(e)
    nil
  end

  extend self
end
