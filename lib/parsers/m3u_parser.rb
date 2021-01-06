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

    file_content = io.read(io.size)

    FormatParser::M3U.new(
      format: :m3u,
      size: io.size,
      content: file_content
    )
  end
  FormatParser.register_parser new, natures: :text, formats: [:m3u, :m3u8]
end
