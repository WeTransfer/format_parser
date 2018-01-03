require 'exifr/jpeg'
require 'exifr/tiff'

class FormatParser::EXIFParser
  include FormatParser::IOUtils

  # Squash exifr's invalid date warning since we do not use that data.
  logger = Logger.new(nil)
  EXIFR.logger = logger

  attr_accessor :exif_data, :orientation, :width, :height

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

  def initialize(filetype, file_data)
    @filetype = filetype
    @file_data = file_data
    @exif_data = nil
    @orientation = nil
    @height = nil
    @width = nil
  end

  def scan_image_exif

    # Without the magic bytes EXIFR throws an error
    @file_data.seek(0)
    raw_exif_data = EXIFR::JPEG.new(@file_data) if @filetype == :jpeg
    raw_exif_data = EXIFR::TIFF.new(@file_data) if @filetype == :tiff
    # For things that we don't yet have a parser for
    # we make the raw exif result available
    @exif_data = raw_exif_data
    @orientation = orientation_parser(raw_exif_data)
    @width = @exif_data.width
    @height = @exif_data.height
  end

  def orientation_parser(raw_exif_data)
    value = raw_exif_data.orientation.to_i
    if valid_orientation?(value)
      @orientation = ORIENTATIONS[value - 1]
    end
  end

  def valid_orientation?(value)
    (1..ORIENTATIONS.length).include?(value)
  end

end
