class FormatParser::PDFParser
  include FormatParser::IOUtils
  # First 9 bytes of a PDF should be in this format, according to:
  #
  #  https://stackoverflow.com/questions/3108201/detect-if-pdf-file-is-correct-header-pdf
  #
  # There are however exceptions, which are left out for now.
  #
  PDF_MARKER = /%PDF-[12]\.[0-8]{1}/
  PDF_CONTENT_TYPE = 'application/pdf'

  def likely_match?(filename)
    filename =~ /\.(pdf|ai)$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    header = safe_read(io, 9)
    return unless header =~ PDF_MARKER

    FormatParser::Document.new(format: :pdf, content_type: PDF_CONTENT_TYPE)
  rescue FormatParser::IOUtils::InvalidRead
    nil
  end

  FormatParser.register_parser new, natures: :document, formats: :pdf, priority: 3
end
