require 'exifr/jpeg'

class FormatParser::EXIFParser

  WIDTH_TAG = 0x0100
  HEIGHT_TAG = 0x0101
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
    @width = nil
    @short = nil
    @long = nil
  end

  def scan_jpeg
    @exif_data.rewind
    EXIFR::JPEG.new(@exif_data)
  end

  def scan_endianness
    @exif_data.seek(30)
    magic_bytes = @exif_data.read(2).unpack("C2")
    if magic_bytes[0..1] == [0x4D, 0x4D]
      @short, @long = "n", "N"
    else
      @short, @long = "v", "V"
    end
  end

  # Once we're at the right place figure out how many tags we need to parse
  def scan_file_data
    # Grab the position here and then look forward for the tags we need
    scan_endianness
    check_place = @exif_data.read(5).unpack(@short)
    # Make sure we're at the right place in the EXIF metadata
    if check_place.first == 42
      # @exif_data.seek(42)
      tag_count = @exif_data.read(5).unpack(@short).first
      tag_count.downto(1) do
        exif_width_parser
        exif_height_parser
        # exif_orientation_parser
      end
    end
  end

  # Make sure we're looking at the right tag
  def exif_orientation_parser
    tag = @exif_data[10..11].unpack(@short).first
    if tag == ORIENTATION_TAG
      orientation_type_parser
    end
  end

  def exif_width_parser
    @exif_data.seek(67)
    tag = @exif_data.read(2).unpack(@short).first
    if tag == WIDTH_TAG
      @exif_data.read(6)
      @width = @exif_data.read(2).unpack(@short)
    end
  end

  def exif_height_parser
    tag = @exif_data.read(5).unpack(@short).first
    if tag == HEIGHT_TAG
      @height = @exif_data.read(2).unpack(@short)
    end
  end

  # Depending on type, find the orientation number
  def orientation_type_parser
    type = @exif_data[12..18].unpack(@short).first
    if type == 3
      @exif_data[15..21].unpack(@short).first
    elsif type == 4
      @exif_data[15..21].unpack(@long).first
    end
  end

  # Make sure the orientation we found is valid
  def valid_orientation?(value)
    (1..ORIENTATIONS.length).include?(value)
  end

end
