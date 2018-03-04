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
  COUNT_MARKERS = ['Count ']
  EOF_MARKER    = '%EOF'

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless safe_read(io, 9) =~ PDF_MARKER

    attributes = scan_for_attributes(io)

    FormatParser::Document.new(
      format: :pdf,
      page_count: attributes[:page_count]
    )
  end

  private

  # Read ahead bytes until one of % or / is reached.
  # A header in a PDF always starts with a /
  # The % is to detect the EOF
  #
  def scan_for_attributes(io)
    result = {}

    while read = safe_read(io, 1)
      case read
      when '%'
        break if safe_read(io, EOF_MARKER.size) == EOF_MARKER
      when '/'
        find_page_count(io, result)
      end
    end

    result
  end

  def find_page_count(io, result)
    COUNT_MARKERS.each do |marker|
      if safe_read(io, marker.size) == marker
        result[:page_count] = read_numbers(io)
      end
    end
  end

  # Read ahead bytes until no more numbers are found
  # This assumes that the position of io starts at a
  # number
  def read_numbers(io)
    numbers = ''

    while c = safe_read(io, 1)
      c =~ /\d+/ ? numbers << c : break
    end

    numbers.to_i
  end

  FormatParser.register_parser self, natures: :document, formats: :pdf
end
