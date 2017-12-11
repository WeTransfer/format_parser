class FormatParser::EXIFParser

  ORIENTATION_TAG = 0x0112
  ORIENTATIONS = [
    :top_left,
    :top_right,
    :bottom_right,
    :bottom_left,
    :left_top,
    :right_top,
    :right_bottom,
    :left_bottom
  ]
  include FormatParser::IOUtils

  def initialize(exif_data)
    @exif_data = exif_data
    @orientation = nil
    @endianness = nil
  end

  def scan
    @endianness = scan_endianness
    scan_and_skip_to_offset
    scan_ifd do |tag|
      if tag == ORIENTATION_TAG
        value = read_integer_value
        if valid_orientation?(value)
          @orientation = ORIENTATIONS[value - 1]
        end
      end
    end

    @orientation
  end

  # def scan_header
  #   # scan_endianness
  #   # scan_tag_mark
  #   scan_and_skip_to_offset
  # end

  def scan_endianness
    magic_bytes = safe_read(@exif_data, 2).unpack("C2")
    magic_bytes[0..1] == [0x4D, 0x4D] ? "n" : "v"
  end
  #
  # def scan_tag_mark
  #   raise_scan_error unless safe_read(@buf, 2).unpack("C2") == 0x002A
  # end

  def scan_and_skip_to_offset
    offset = safe_read(@exif_data, 4).unpack(@endianness.upcase)
    cache = Care::IOWrapper.new(@exif_data)
    cache.seek(offset)
  end

  def scan_ifd
    offset = 0
    entry_count = read_short

    entry_count.first.times do |i|
      @exif_data.seek(offset + 2 + (12 * i))
      tag = read_short
      return tag
    end
  end

  def read_short
    safe_read(@exif_data, 2).unpack(@endianness)
  end

  # def scan_ifd
  #   offset = 0
  #   entry_count = read_short
  #
  #   tag = entry_count.times do |i|
  #     cache = Care::IOWrapper.new(@exif_data)
  #     cache.seek(offset + 2 + (12 * i))
  #   end
  #   tag
  # end
  #
  # def read_short
  #   endianness = detect_endianness
  #   @exif_data.unpack("x12" + endianness + "2").first
  # end

  def valid_orientation?(value)
    (1..ORIENTATIONS.length).include?(value)
  end

  def detect_endianness
    if @exif_data[0..1] == "II"
    endianness = "v"
    elsif @exif_data[0..1] == "MM"
      endianness = "n"
    else
      endianness = nil
    end
    endianness
  end

end
