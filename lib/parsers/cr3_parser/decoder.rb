require 'parsers/iso_base_file_format/decoder'

class FormatParser::CR3Parser::Decoder < FormatParser::Decoder
  include FormatParser::EXIFParser

  protected

  ATOM_PARSERS = ATOM_PARSERS.merge({
    'CMT1' => :cmt1
  })
  CANON_METADATA_CONTAINER_UUID = '85c0b687820f11e08111f4ce462b6a48'

  def cmt1(size)
    exif = exif_from_tiff_io(StringIO.new(read_bytes(size)))
    if exif
      fields = exif.to_hash
      fields[:rotated] = exif.rotated?
      fields[:orientation_sym] = exif.orientation_sym
      [fields, nil]
    else
      [nil, nil]
    end
  end

  def uuid(size)
    usertype = read_bytes(16).unpack('H*').first
    fields = { usertype: usertype }
    children = if usertype == CANON_METADATA_CONTAINER_UUID
      build_atom_tree(size - 16)
    else
      skip_bytes(size - 16)
    end
    [fields, children]
  end
end
