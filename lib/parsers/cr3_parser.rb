class FormatParser::CR3Parser
  include FormatParser::IOUtils
  require_relative 'cr3_parser/decoder'

  CR3_MIME_TYPE = 'image/x-canon-cr3'

  def likely_match?(filename)
    filename =~ /\.cr3$/i
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    return unless matches_cr3_definition?

    atom_tree = Decoder.new.build_atom_tree(0xffffffff, @buf)
    moov_atom = atom_tree.find { |atom| atom.type == 'moov' }
    cmt1_atom = moov_atom&.find_first_descendent(['CMT1'])
    return unless cmt1_atom

    width = cmt1_atom.fields[:image_width]
    height = cmt1_atom.fields[:image_length]
    rotated = cmt1_atom.fields[:rotated]
    orientation = cmt1_atom.fields[:orientation_sym]
    FormatParser::Image.new(
      format: :cr3,
      content_type: CR3_MIME_TYPE,
      width_px: width,
      height_px: height,
      orientation: orientation,
      display_width_px: rotated ? height : width,
      display_height_px: rotated ? width : height,
      intrinsics: {
        atom_tree: atom_tree,
        exif: cmt1_atom.fields,
      },
    )
  end

  private

  def matches_cr3_definition?
    matches = skip_bytes_then(4) { read_string(8) } == 'ftypcrx '
    @buf.seek(0)
    matches
  end

  FormatParser.register_parser new, natures: [:image], formats: [:cr3]
end
