class FormatParser::JPEGParser
  include FormatParser::IOUtils

  class InvalidStructure < StandardError
  end

  SOI_MARKER = 0xD8 # start of image
  SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
  EOI_MARKER  = 0xD9  # end of image
  SOS_MARKER  = 0xDA  # start of stream
  APP1_MARKER = 0xE1  # maybe EXIF
  EXIF_MAGIC_STRING = "Exif\0\0".b
  MAX_GETBYTE_CALLS_WHEN_LOOKING_FOR_MARKER = 1023

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

    markers_start_at = @buf.pos

    # Keynote files start with a series of _perfectly_ valid
    # JPEG markers, probably for icon previews or QuickLook.
    # We have to detect those and reject them earlier. We can
    # make use of our magic ZIP reader to get there.
    return if probably_keynote_zip?

    @buf.seek(markers_start_at)

    while marker = read_next_marker
      case marker
      when *SOF_MARKERS
        scan_start_of_frame
      when EOI_MARKER, SOS_MARKER
        # When we reach "End of image" or "Start of scan" markers
        # we are transitioning into the image data that we don't need
        # or we have reached EOF.
        break
      when APP1_MARKER
        scan_app1_frame
      else
        skip_frame
      end
    end

    FormatParser::Measurometer.add_distribution_value('format_parser.JPEGParser.bytes_read_until_capture', @buf.pos)

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

    nil # We could not parse anything
  rescue InvalidStructure
    nil # Due to the way JPEG is structured it is possible that some invalid inputs will get caught
  end

  # Read a byte, if it is 0xFF then skip bytes as long as they are also 0xFF (byte stuffing)
  # and return the first byte scanned that is not 0xFF. Also applies limits so that we do not
  # read for inordinate amount of time should we encounter a file where we _do_ have a SOI
  # marker at the start and then no markers for a _very_ long time (happened with some PSDs)
  def read_next_marker
    max_two_byte_reads = MAX_GETBYTE_CALLS_WHEN_LOOKING_FOR_MARKER / 2
    max_two_byte_reads.times do
      previous = read_char
      current = read_char
      return current if previous == 0xFF && current != 0xFF
    end
    nil # Nothing found
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
    # Read the entire EXIF frame at once to not overload the number of reads. If we don't,
    # EXIFR parses our file from the very beginning and does the same parsing we do, just
    # the second time around. What we care about, rather, is the EXIF data only. So we will
    # pry it out of the APP1 frame and parse it as the TIFF segment - which is what EXIFR
    # does under the hood.
    app1_frame_content_length = read_short - 2

    # Peek whether the contents of the marker starts with Exif\0
    maybe_exif_magic_str = safe_read(@buf, EXIF_MAGIC_STRING.bytesize)

    # If we could not find the magic Exif\0 string at the start of the marker,
    # seek to the start of the next marker and return
    unless maybe_exif_magic_str == EXIF_MAGIC_STRING
      safe_skip(@buf, app1_frame_content_length - EXIF_MAGIC_STRING.bytesize)
      return
    end

    # ...and only then read the marker contents and parse it as EXIF
    exif_data = safe_read(@buf, app1_frame_content_length - EXIF_MAGIC_STRING.bytesize)

    FormatParser::Measurometer.add_distribution_value('format_parser.JPEGParser.bytes_sent_to_exif_parser', exif_data.bytesize)
    scanner = FormatParser::EXIFParser.new(StringIO.new(exif_data))
    scanner.scan_image_tiff

    @exif_output = scanner.exif_data
    @orientation = scanner.orientation unless scanner.orientation.nil?
    @intrinsics[:exif_pixel_x_dimension] = @exif_output.pixel_x_dimension
    @intrinsics[:exif_pixel_y_dimension] = @exif_output.pixel_y_dimension
    # Save these two for later, when we decide to provide display width /
    # display height in addition to pixel buffer width / height. These two
    # are _different concepts_. Imagine you have an image shot with a camera
    # in portrait orientation, and the camera has an anamorphic lens. That
    # anamorpohic lens is a smart lens, and therefore transmits pixel aspect
    # ratio to the camera, and the camera encodes that aspect ratio into the
    # image metadata. If we want to know what size our _pixel buffer_ will be,
    # and how to _read_ the pixel data (stride/interleaving) - we need the
    # pixel buffer dimensions. If we want to know what aspect and dimensions
    # our file is going to have _once displayed_ and _once pixels have been
    # brought to the right orientation_ we need to work with **display dimensions**
    # which can be remarkably different from the pixel buffer dimensions.
    @exif_width = scanner.width
    @exif_height = scanner.height
  rescue EXIFR::MalformedTIFF
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

  def probably_keynote_zip?
    reader = FormatParser::ZIPParser::FileReader.new
    reader.zip?(@buf)
  end

  FormatParser.register_parser self, natures: :image, formats: :jpg
end
