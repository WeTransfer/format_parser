class FormatParser::CR3Parser
  include FormatParser::IOUtils
  require_relative 'cr3_parser/decoder'

  CR3_MIME_TYPE = 'image/x-canon-cr3'
  MAGIC_BYTES = 'ftypcrx '

  def likely_match?(filename)
    filename =~ /\.cr3$/i
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    return unless matches_cr3_definition?

    box_tree = Measurometer.instrument('format_parser.cr3_parser.decoder.build_box_tree') do
      Decoder.new.build_box_tree(0xffffffff, @buf)
    end
    moov_box = box_tree.find { |box| box.type == 'moov' }
    cmt1_box = moov_box&.first_descendent('CMT1')
    return unless cmt1_box

    width = cmt1_box.fields[:image_width]
    height = cmt1_box.fields[:image_length]
    rotated = cmt1_box.fields[:rotated]
    orientation = cmt1_box.fields[:orientation_sym]
    FormatParser::Image.new(
      format: :cr3,
      content_type: CR3_MIME_TYPE,
      width_px: width,
      height_px: height,
      orientation: orientation,
      display_width_px: rotated ? height : width,
      display_height_px: rotated ? width : height,
      intrinsics: {
        box_tree: box_tree,
        exif: cmt1_box.fields,
      },
    )
  end

  private

  def matches_cr3_definition?
    skip_bytes(4)
    matches = read_string(8) == MAGIC_BYTES
    @buf.seek(0)
    matches
  end

  FormatParser.register_parser new, natures: [:image], formats: [:cr3]
end
