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
  MARKERS = { page_count: 'Count ' }
  MAX_BYTES_TO_READ = 1024

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

  # Private: Read ahead n bytes until all the MARKERS are found or the io is
  # at the end.
  # A header in a PDF always starts with a /. When a / is found in a
  # serie of bytes the io rewinds until the beginning of the first character
  # after that / and extracts the appropriate information.
  #
  def scan_for_attributes(io)
    result = {}

    bytes_read = MAX_BYTES_TO_READ

    while read = safe_read(io, bytes_read)
      if pos = read.index('/')
        io.seek(io.pos - read.size + pos + 1)

        find_marker(io, result)
      end

      left = io.size - io.pos
      bytes_read = left > MAX_BYTES_TO_READ ? MAX_BYTES_TO_READ : left

      break if stop_looking?(result) || bytes_read.zero?
    end

    result
  end

  # Private: Checks if all the markers are already found.
  #
  # Returns a boolean
  def stop_looking?(result)
    MARKERS.keys.all? do |key|
      result.has_key?(key)
    end
  end

  # Private: Finds a marker from the hash of MARKERS and assign the appropriate
  # attribute to result.
  def find_marker(io, result)
    MARKERS.each do |attr, marker|
      result[attr] = read_numbers(io) if safe_read(io, marker.size) == marker
    end
  end

  # Private: Read ahead bytes until no more numbers are found
  # This assumes that the position of io starts at a number
  def read_numbers(io)
    numbers = ''

    while c = safe_read(io, 1)
      c =~ /\d+/ ? numbers << c : break
    end

    numbers.to_i
  end

  FormatParser.register_parser self, natures: :document, formats: :pdf
end
