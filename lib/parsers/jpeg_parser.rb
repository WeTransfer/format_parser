class FormatParser::JPEGParser
  include FormatParser::IOUtils

  SOI_MARKER = 0xD8 # start of image
  SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
  EOI_MARKER  = 0xD9  # end of image
  SOS_MARKER  = 0xDA  # start of stream
  APP1_MARKER = 0xE1  # maybe EXIF

  def information_from_io(io)
    @buf = io
    @buf.seek(0)
    @width             = nil
    @height            = nil
    @orientation       = 1
    scan
  end

  private

  def advance(n)
    safe_read(@buf, n); nil
  end

  def read_char
    safe_read(@buf, 1).unpack('C').first
  end

  def read_short
    safe_read(@buf, 2).unpack('n*').first
  end

  def scan
    # Return early if it is not a JPEG at all
    signature = read_next_marker
    return unless signature == SOI_MARKER

    while marker = read_next_marker
      case marker
      when *SOF_MARKERS
        scan_start_of_frame
      when EOI_MARKER, SOS_MARKER
        break
      when APP1_MARKER
        scan_app1_frame
      else
        skip_frame
      end

      # Return at the earliest possible opportunity
      if @width && @height && @orientation
        file_info = FormatParser::FileInformation.image(
          file_type: :jpg,
          width_px: @width,
          height_px: @height,
          orientation: @orientation
        )
        return file_info
      elsif @width && @height
        file_info = FormatParser::FileInformation.image(
          file_type: :jpg,
          width_px: @width,
          height_px: @height
        )
        return file_info
      end
    end
    nil # We could not parse anything
  end


  # Read a byte, if it is 0xFF then skip bytes as long as they are also 0xFF (byte stuffing)
  # and return the first byte scanned that is not 0xFF
  def read_next_marker
    c = read_char while c != 0xFF
    c = read_char while c == 0xFF
    c
  end

  def scan_start_of_frame
    length = read_short
    read_char # depth, unused
    height = read_short
    width  = read_short
    size   = read_char

    if length == (size * 3) + 8
      @width, @height = width, height
    else
      raise_scan_error
    end
  end

  def scan_app1_frame
    frame = @buf.read(8)
    if frame.include?("Exif")
      scanner = FormatParser::EXIFParser.new(@buf)
      exif_data = scanner.scan_jpeg
      if exif_data
        orientation_raw = exif_data.exif.orientation
        @exif_output = exif_data
        @orientation = exif_data.exif.orientation.to_i unless orientation_raw.nil?
        @width = exif_data.exif.pixel_x_dimension || @exif_output.height
        @height = exif_data.exif.pixel_y_dimension || @exif_output.width
      end
    end
  end

  def read_frame
    length = read_short - 2
    safe_read(@buf, length)
  end

  def skip_frame
    length = read_short - 2
    advance(length)
  end

  FormatParser.register_parser_constructor self
end
