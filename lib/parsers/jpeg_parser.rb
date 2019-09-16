class FormatParser::JPEGParser
  include FormatParser::IOUtils
  include FormatParser::EXIFParser

  class InvalidStructure < StandardError
  end

  JPEG_SOI_MARKER_HEAD = [0xFF, 0xD8].pack('C2')
  SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
  EOI_MARKER  = 0xD9  # end of image
  SOS_MARKER  = 0xDA  # start of stream
  APP1_MARKER = 0xE1  # maybe EXIF
  EXIF_MAGIC_STRING = "Exif\0\0".b
  MUST_FIND_NEXT_MARKER_WITHIN_BYTES = 1024

  def self.likely_match?(filename)
    filename =~ /\.jpe?g$/i
  end

  def self.call(io)
    new.call(io)
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)
    @width             = nil
    @height            = nil
    @exif_data_frames  = []
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
    # Most JPEG images start with the 0xFF0xD8 SOI marker.
    # We _can_ search for that marker, but we will then
    # ambiguously capture things like JPEGs embedded in ID3
    # tags of MP3s - these _are_ JPEGs but we care much
    # more about the top-level "wrapper" file, not about
    # it's bits and bobs
    return unless safe_read(@buf, 2) == JPEG_SOI_MARKER_HEAD

    markers_start_at = @buf.pos

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

    Measurometer.add_distribution_value('format_parser.JPEGParser.bytes_read_until_capture', @buf.pos)

    # A single file might contain multiple EXIF data frames. In a JPEG this would
    # manifest as multiple APP1 markers. The way different programs handle these
    # differs, for us it makes the most sense to simply "flatten" them top-down.
    # So we start with the first EXIF frame, and we then allow the APP1 markers
    # that come later in the file to override the properties they _do_ specify.
    flat_exif = FormatParser::EXIFParser::EXIFStack.new(@exif_data_frames)

    # Return at the earliest possible opportunity
    if @width && @height
      dw, dh = flat_exif.rotated? ? [@height, @width] : [@width, @height]
      result = FormatParser::Image.new(
        format: :jpg,
        width_px: @width,
        height_px: @height,
        display_width_px: dw,
        display_height_px: dh,
        orientation: flat_exif.orientation_sym,
        intrinsics: {exif: flat_exif},
      )

      return result
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
    # We need to find a sequence of two bytes - the first one is 0xFF, the other is anything but 0xFF
    a = read_char
    (MUST_FIND_NEXT_MARKER_WITHIN_BYTES - 1).times do
      b = read_char
      return b if a == 0xFF && b != 0xFF # Caught the marker
      a = b # Shift the tuple one byte forward
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
    marker_length_at = @buf.pos
    app1_frame_content_length = read_short - 2

    # If there is certainly not enough data in this APP1 to begin with, bail out.
    # For the sake of the argument assume that a usable EXIF marker would contain
    # at least 2 bytes of data - not exact science, but it can help us
    # avoid reading _anything_ from the APP1 marker body if it's too small anyway
    return if app1_frame_content_length < (EXIF_MAGIC_STRING.bytesize + 2)

    # Peek whether the contents of the marker starts with Exif\0
    maybe_exif_magic_str = safe_read(@buf, EXIF_MAGIC_STRING.bytesize)

    # If we could not find the magic Exif\0 string at the start of the marker,
    # seek to the start of the next marker and return
    return unless maybe_exif_magic_str == EXIF_MAGIC_STRING

    # ...and only then read the marker contents and parse it as EXIF.
    # Use StringIO.new instead of #write - https://github.com/aws/aws-sdk-ruby/issues/785#issuecomment-95456838
    exif_buf = StringIO.new(safe_read(@buf, app1_frame_content_length - EXIF_MAGIC_STRING.bytesize))

    Measurometer.add_distribution_value('format_parser.JPEGParser.bytes_sent_to_exif_parser', exif_buf.size)

    @exif_data_frames << exif_from_tiff_io(exif_buf)
  rescue EXIFR::MalformedTIFF
    # Not a JPEG or the Exif headers contain invalid data, or
    # an APP1 marker was detected in a file that is not a JPEG
  ensure
    # Reposition the file pointer to where the next marker will begin,
    # regardless whether we did find usable EXIF or not
    @buf.seek(marker_length_at + 2 + app1_frame_content_length)

    # Make sure to explicitly clear the EXIF buffers since they can be large
    exif_buf.truncate(0) if exif_buf
  end

  def read_frame
    length = read_short - 2
    safe_read(@buf, length)
  end

  def skip_frame
    length = read_short - 2
    safe_skip(@buf, length)
  end

  FormatParser.register_parser self, natures: :image, formats: :jpg, priority: 0
end
