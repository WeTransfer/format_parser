class FormatParser::PDFParser
  include FormatParser::IOUtils

  # First 9 bytes of a PDF should be in this format, according to:
  #
  #  https://stackoverflow.com/questions/3108201/detect-if-pdf-file-is-correct-header-pdf
  #
  # There are however exceptions, which are left out for now.
  #
  PDF_MARKER = /%PDF-1\.[0-8]{1}/

  def likely_match?(filename)
    filename =~ /\.(pdf|ai)$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless safe_read(io, 9) =~ PDF_MARKER

    FormatParser::Document.new(format: :pdf)
  end

  FormatParser.register_parser new, natures: :document, formats: :pdf, priority: 1
end
