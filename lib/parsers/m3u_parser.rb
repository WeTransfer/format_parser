class FormatParser::M3UParser
  include FormatParser::IOUtils

  HEADER = '#EXTM3U'
  M3U8_MIME_TYPE = 'application/vnd.apple.mpegurl' # https://en.wikipedia.org/wiki/M3U#Internet_media_types

  def likely_match?(filename)
    filename =~ /\.m3u8?$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    header = safe_read(io, 7)
    return unless HEADER.eql?(header)

    FormatParser::Text.new(
      format: :m3u,
      content_type: M3U8_MIME_TYPE,
    )
  end
  FormatParser.register_parser new, natures: :text, formats: :m3u
end
