class FormatParser::MOOVParser
  include FormatParser::IOUtils
  include FormatParser::DSL
  require_relative 'moov_parser/decoder'

  # Maps values of the "ftyp" atom to something
  # we can reasonably call "file type" (something
  # usable as a filename extension)
  FTYP_MAP = {
    "qt  " => :mov,
    "mp4 " => :mp4,
    "m4a " => :m4a,
  }

  natures :video
  formats *FTYP_MAP.values

  # It is currently not documented and not particularly well-tested,
  # so not considered a public API for now
  private_constant :Decoder

  def call(io)
    return nil unless matches_moov_definition?(io)

    # Now we know we are in a MOOV, so go back and parse out the atom structure.
    # Parsing out the atoms does not read their contents - at least it doesn't
    # for the atoms we consider opaque (one of which is the "mdat" atom which
    # will be the prevalent part of the file body). We do not parse these huge
    # atoms - we skip over them and note where they are located.
    io.seek(0)

    # We have to tell the parser how far we are willing to go within the stream.
    # Knowing that we will bail out early anyway we will permit a large read. The
    # branch parse calls will know the maximum size to read from the parent atom
    # size that gets parsed just before.
    max_read_offset = 0xFFFFFFFF
    decoder = Decoder.new
    atom_tree = decoder.extract_atom_stream(io, max_read_offset)

    ftyp_atom = decoder.find_first_atom_by_path(atom_tree, 'ftyp')
    file_type = ftyp_atom.field_value(:major_brand)

    width, height = nil, nil

    # Try to find the width and height in the tkhd
    if tkhd = decoder.find_first_atom_by_path(atom_tree, 'moov', 'trak', 'tkhd')
      width = tkhd.field_value(:track_width).first
      height = tkhd.field_value(:track_height).first
    end

    # Try to find the "topmost" duration (respecting edits)
    if mdhd = decoder.find_first_atom_by_path(atom_tree, 'moov', 'mvhd')
      timescale, duration = mdhd.field_value(:tscale), mdhd.field_value(:duration)
      media_duration_s = duration / timescale.to_f
    end

    FormatParser::Video.new(
      format: format_from_moov_type(file_type),
      width_px: width,
      height_px: height,
      media_duration_seconds: media_duration_s,
      intrinsics: atom_tree,
    )
  end

  private

  def format_from_moov_type(file_type)
    FTYP_MAP.fetch(file_type, :mov)
  end

  # An MPEG4/MOV/M4A will start with the "ftyp" atom. The atom must have a length
  # of at least 8 (to accomodate the atom size and the atom type itself) plus the major
  # and minor version fields. If we cannot find it we can be certain this is not our file.
  def matches_moov_definition?(io)
    maybe_atom_size, maybe_ftyp_atom_signature = safe_read(io, 8).unpack('N1a4')
    minimum_ftyp_atom_size = 4 + 4 + 4 + 4
    maybe_atom_size >= minimum_ftyp_atom_size && maybe_ftyp_atom_signature == 'ftyp'
  end

  FormatParser.register_parser_constructor self
end
