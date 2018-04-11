class FormatParser::JPEGParser
  include FormatParser::IOUtils

  class InvalidStructure < StandardError
  end

  SOI_MARKER = 0xD8 # start of image
  SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
  EOI_MARKER  = 0xD9  # end of image
  SOS_MARKER  = 0xDA  # start of stream
  APP1_MARKER = 0xE1  # maybe EXIF

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)
    @width             = nil
    @height            = nil
    @orientation       = nil
    @intrinsics = {}
    scan
  end

  private

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
      if @width && @height
        return  FormatParser::Image.new(
          format: :jpg,
          width_px: @width,
          height_px: @height,
          orientation: @orientation,
          intrinsics: @intrinsics,
        )
      end
    end
    nil # We could not parse anything
  rescue InvalidStructure
    nil # Due to the way JPEG is structured it is possible that some invalid inputs will get caught
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
      @width = width
      @height = height
    else
      raise InvalidStructure
    end
  end

  def scan_app1_frame
    frame = @buf.read(8)
    if frame.include?('Exif')
      scanner = FormatParser::EXIFParser.new(:jpeg, @buf)
      if scanner.scan_image_exif
        @exif_output = scanner.exif_data
        @orientation = scanner.orientation unless scanner.orientation.nil?
        @intrinsics[:exif_pixel_x_dimension] = @exif_output.pixel_x_dimension
        @intrinsics[:exif_pixel_y_dimension] = @exif_output.pixel_y_dimension
        @width = scanner.width
        @height = scanner.height
      end
    end
  rescue EXIFR::MalformedJPEG
    # Not a JPEG or the Exif headers contain invalid data, or
    # an APP1 marker was detected in a file that is not a JPEG
  end

  def read_frame
    length = read_short - 2
    safe_read(@buf, length)
  end

  def skip_frame
    length = read_short - 2
    safe_skip(@buf, length)
  end

  FormatParser.register_parser self, natures: :image, formats: :jpg
end
