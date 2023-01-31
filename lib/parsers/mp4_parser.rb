require_relative 'iso_base_media_file_format/decoder'

class FormatParser::MP4Parser
  include FormatParser::IOUtils
  include FormatParser::ISOBaseMediaFileFormat
  include FormatParser::ISOBaseMediaFileFormat::Utils

  MAGIC_BYTES = /^ftyp(iso[m2]|mp4[12]|m4[abprv] )$/i

  BRAND_FORMATS = {
    'isom' => :mp4, # Prohibited as a major brand by ISO/IEC 14496-12 sec 6.3 paragraph 2, but occasionally used.
    'iso2' => :mp4, # Prohibited as a major brand by ISO/IEC 14496-12 sec 6.3 paragraph 2, but occasionally used.
    'mp41' => :mp4,
    'mp42' => :mp4,
    'm4a ' => :m4a,
    'm4b ' => :m4b, # iTunes audiobooks
    'm4p ' => :m4p, # iTunes audio
    'm4r ' => :m4r, # iTunes ringtones
    'm4v ' => :m4v, # iTunes video
  }
  AUDIO_FORMATS = Set[:m4a, :m4b, :m4p, :m4r]
  VIDEO_FORMATS = Set[:mp4, :m4v]

  AUDIO_MIMETYPE = 'audio/mp4'
  VIDEO_MIMETYPE = 'video/mp4'

  def likely_match?(filename)
    /\.(mp4|m4[abprv])$/i.match?(filename)
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    return unless matches_mp4_definition?

    box_tree = Measurometer.instrument('format_parser.mp4_parser.decoder.build_box_tree') do
      Decoder.new.build_box_tree(0xffffffff, @buf)
    end

    case file_format = file_format(box_tree)
    when VIDEO_FORMATS
      width, height = dimensions(box_tree)
      FormatParser::Video.new(
        codecs: codecs(box_tree),
        content_type: VIDEO_MIMETYPE,
        format: file_format,
        frame_rate: frame_rate(box_tree),
        height_px: height,
        intrinsics: box_tree,
        media_duration_seconds: duration(box_tree),
        width_px: width,
      )
    when AUDIO_FORMATS
      FormatParser::Audio.new(
        content_type: AUDIO_MIMETYPE,
        format: file_format,
        intrinsics: box_tree,
        media_duration_seconds: duration(box_tree),
      )
    else
      nil
    end
  end

  private

  def file_format(box_tree)
    BRAND_FORMATS[box_tree.find { |box| box.type == 'ftyp' }[:major_brand]]
  end

  def matches_mp4_definition?
    skip_bytes(4)
    matches = MAGIC_BYTES.match?(read_string(8))
    @buf.seek(0)
    matches
  end

  FormatParser.register_parser new, natures: [:audio, :video], formats: BRAND_FORMATS.values.uniq, priority: 3
end
