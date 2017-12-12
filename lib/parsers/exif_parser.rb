require_relative '../care'

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

  attr_reader :orientation

  def initialize(exif_data)
    @exif_data = exif_data
    @orientation = nil
    @rotated = false
    @short = nil
    @long = nil
  end

  def scan
    scan_endianness
    # cache = scan_and_skip_to_offset
    value = scan_ifd
    if valid_orientation?(value)
      @orientation = ORIENTATIONS[value - 1]
    end

    @orientation
  end

  def scan_endianness
    magic_bytes = @exif_data[0..1].unpack("C2")
    if magic_bytes[0..1] == [0x4D, 0x4D]
      @short, @long = "n", "N"
    else
      @short, @long = "v", "V"
    end
  end

  def scan_and_skip_to_offset
    offset = safe_read(@exif_data, 4).unpack(@long)
    cache = Care::IOWrapper.new(@exif_data)
    cache.seek(offset)
  end

  def scan_ifd
    check_place = @exif_data[2..3].unpack(@short)
    # Make sure we're at the right place in the EXIF metadata
    if check_place.first == 42
      tag_count = @exif_data[8..9].unpack(@short).first
      tag_count.downto(1) do
        exif_tag_parser
      end
    end
  end

  def exif_tag_parser
    tag = @exif_data[10..11].unpack(@short).first
    if tag == ORIENTATION_TAG
      orientation_type_parser
    end
  end

  def orientation_type_parser
    type = @exif_data[12..18].unpack(@short).first
    if type == 3
      @exif_data[15..21].unpack(@short).first
    elsif type == 4
      @exif_data[15..21].unpack(@long).first
    end
  end

  def valid_orientation?(value)
    (1..ORIENTATIONS.length).include?(value)
  end

end
