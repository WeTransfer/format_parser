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
  EOF_MARKER = '%%EOF'

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    return unless safe_read(io, 9) =~ PDF_MARKER

    @xref_table = XRefTable.parse(io)

    FormatParser::Document.new(
      format: :pdf,
      page_count: page_count(io)
    )
  end

  private

  # Fetches the page count
  #
  # Loops over @xref_table objects and tries to extract the page count
  # from the PDF objects. It does so by peaking ahead in the io if a
  # certain dictionary (<<...>>) header is matched. Then it parses
  # the object with PDFObjectReader and reads :count.
  def page_count(io)
    page_count = nil

    @xref_table.each do |xref|
      io.seek(xref.offset)

      page_count = case safe_read(io, 32)
                   when /\/Type\s*\/Pages/,
                        /\/Linearized/
                     PDFObjectReader.parse(io, xref)[:count]
                   end

      break if page_count
    end

    page_count
  end

  # Module which converts a PDF object to a Hash
  module PDFObjectReader
    module_function

    extend FormatParser::IOUtils

    KEYWORDS = {
      /Type\/(\w+)/       => :type,
      /Pages\s*([ 0-9R])/ => :pages,
      /Count\s*(\d+)/     => :count,
      /N\s*(\d+)/         => :count
    }

    def parse(io, xref)
      io.seek(xref.offset)

      obj = raw_object(io)

      KEYWORDS.each_with_object({}) do |(extractor, keyword), result|
        next unless obj.index(extractor)

        value = obj.match(extractor).captures[0]

        result[keyword] = case keyword
                          when :count
                            value.to_i
                          else
                            value
                          end
      end
    end

    # Reads the full object till the end of the object
    # An object ends with 'endobj'
    def raw_object(io)
      obj = ''

      while byte = safe_read(io, 1)
        obj << byte

        break if obj.end_with?('endobj')
      end

      obj
    end
  end

  # Start XRefTable
  module XRefTable
    module_function

    extend FormatParser::IOUtils

    class XRefTableCountError < StandardError; end

    XRef = Struct.new(:idx, :offset, :generation_number, :entry_type)

    # Public: parse
    #
    # Returns an array of XRef objects
    def parse(io)
      io.seek(io.size - 5)

      table_offset = xref_table_offset(io)
      # TODO: Sometimes the EOF ends with a line-ending
      # return [] unless safe_read(@io, 5) == FormatParser::PDFParser::EOF_MARKER
      return [] unless table_offset

      io.seek(table_offset)

      parse_xref_table(io)
    end

    def xref_table_offset(io)
      # Read the "tail" of the PDF and find the 'startxref' declaration
      xref_table_size = 1024
      tail_pos = xref_table_size > io.size ? 0 : io.size - xref_table_size

      io.seek(tail_pos)
      tail = io.read(xref_table_size)

      # Find the "startxref" declaration and read the first group of integers after it
      start_xref_index = tail.index('startxref')
      return unless start_xref_index

      startxref = tail.byteslice(start_xref_index, xref_table_size)[/\d+/]
      return unless startxref

      startxref.to_i
    end

    def parse_xref_table(io)
      xref_table = []
      starting_idx = 0
      num_objects = nil

      while line = read_until_linebreak(io, char_limit: 32)
        case line
        when /^(\d+) (\d+)$/
          # Defines the starting number of the object and the
          # number of objects in the table
          starting_idx = $1.to_i
          num_objects = $2.to_i
        when /^(\d{10}) (\d{5}) (\w)$/
          # The actual object offset.
          xref_table << XRef.new(
            starting_idx + xref_table.length,
            $1.to_i,
            $2.to_i,
            $3
          )
        when /trailer/
          break
        end
      end

      # Check if the number of xrefs we got makes sense
      if num_objects && num_objects != xref_table.length
        raise XRefTableCountError,
              "The xref table was declared to contain #{num_objects}"\
              "object refs but contained #{xref_table.length}"
      end

      xref_table.sort_by(&:offset).reject do |entry|
        entry.entry_type == 'f'
      end
    end

    def read_until_linebreak(io, char_limit: 32)
      buf = StringIO.new(''.b)
      char_limit.times do
        char = safe_read(io, 1).force_encoding(Encoding::BINARY)
        if char == "\n"
          break
        else
          buf << char
        end
      end
      buf.string.strip
    end
  end

  FormatParser.register_parser self, natures: :document, formats: :pdf
end
