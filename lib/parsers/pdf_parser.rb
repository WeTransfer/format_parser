class FormatParser::PDFParser
  include FormatParser::IOUtils

  # First 9 bytes of a PDF should be in this format, according to:
  #
  #  https://stackoverflow.com/questions/3108201/detect-if-pdf-file-is-correct-header-pdf
  #
  # There are however exceptions, which are left out for now.
  #
  PDF_MARKER = /%PDF-1\.[0-8]{1}/

  # Page counts have different markers depending on
  # the PDF type. There is not a single common way of solving
  # this. The only way of solving this correctly is by adding
  # different types of PDF's in the specs.
  #
  COUNT_MARKER = /\/(N|Count|Page)\s([0-9]+)/

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless safe_read(io, 9) =~ PDF_MARKER

    FormatParser::Document.new(
      format: :pdf,
      page_count: page_count(io)
    )
  end

  private

  def page_count(io)
    io.seek(9)

    while read = safe_read(io, 100)
      if count = read.match(COUNT_MARKER)
        page_count = count.captures.last.to_i
        break
      end
    end

    page_count
  end

  FormatParser.register_parser self, natures: :document, formats: :pdf
end
