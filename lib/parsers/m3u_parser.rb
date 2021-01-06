class FormatParser::M3UParser
  include FormatParser::IOUtils

  HEADER = '#EXTM3U'

  def likely_match?(filename)
    filename =~ /\.(m3u|m3u8)$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    header = safe_read(io, 7)
    return unless HEADER.eql?(header)

    FormatParser::Text.new(
      format: :m3u,
      size: io.size
    )
  end
  FormatParser.register_parser new, natures: :text, formats: [:m3u, :m3u8]
end
