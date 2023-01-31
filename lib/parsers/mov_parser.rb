require 'parsers/iso_base_media_file_format/utils'

class FormatParser::MOVParser
  include FormatParser::IOUtils
  include FormatParser::ISOBaseMediaFileFormat::Utils

  MAGIC_BYTES = 'ftypqt  '
  MOV_MIME_TYPE = 'video/quicktime'

  def likely_match?(filename)
    /\.(mov|moov|qt)$/i.match?(filename)
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    return unless matches_mov_definition?

    box_tree = Measurometer.instrument('format_parser.mov_parser.decoder.build_box_tree') do
      Decoder.new.build_box_tree(0xffffffff, @buf)
    end

    width, height = dimensions(box_tree)

    FormatParser::Video.new(
      format: :mov,
      width_px: width,
      height_px: height,
      frame_rate: frame_rate(box_tree),
      media_duration_seconds: duration(box_tree),
      content_type: MOV_MIME_TYPE,
      codecs: codecs(box_tree),
      intrinsics: box_tree
    )
  end

  private

  def matches_mov_definition?
    skip_bytes(4)
    matches = read_string(8) == MAGIC_BYTES
    @buf.seek(0)
    matches
  end

  FormatParser.register_parser new, natures: [:video], formats: [:mov], priority: 3
end
