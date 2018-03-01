require 'exifr/jpeg'
require 'exifr/tiff'
require 'delegate'

class FormatParser::EXIFParser
  include FormatParser::IOUtils

  # EXIFR kindly requests the presence of a few more methods than what our IOConstraint
  # is willing to provide, but they can be derived from the available ones
  class IOExt < SimpleDelegator
    def readbyte
      if byte = read(1)
        byte.unpack('C').first
      end
    end

    def seek(n, seek_mode = IO::SEEK_SET)
      io = __getobj__
      case seek_mode
      when IO::SEEK_SET
        io.seek(n)
      when IO::SEEK_CUR
        io.seek(io.pos + n)
      when IO::SEEK_END
        io.seek(io.size + n)
      else
        raise Errno::EINVAL
      end
    end

    alias_method :getbyte, :readbyte
  end

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

  def initialize(filetype, file_io)
    @filetype = filetype
    @file_io = IOExt.new(file_io)
    @exif_data = nil
    @orientation = nil
    @height = nil
    @width = nil
  end

  def scan_image_exif
    # Without the magic bytes EXIFR throws an error
    @file_io.seek(0)
    raw_exif_data = EXIFR::JPEG.new(@file_io) if @filetype == :jpeg
    # Return if it's a CR2, which we don't parse yet
    return if cr2_check(@file_io)
    raw_exif_data = EXIFR::TIFF.new(@file_io) if @filetype == :tiff
    # For things that we don't yet have a parser for
    # we make the raw exif result available
    @exif_data = raw_exif_data
    @orientation = orientation_parser(raw_exif_data)
    @width = @exif_data.width
    @height = @exif_data.height
  end

  def orientation_parser(raw_exif_data)
    value = raw_exif_data.orientation.to_i
    @orientation = ORIENTATIONS[value - 1] if valid_orientation?(value)
  end

  def valid_orientation?(value)
    (1..ORIENTATIONS.length).include?(value)
  end

  def cr2_check(_file_io)
    @file_io.seek(8)
    cr2_check_bytes = @file_io.read(2)
    cr2_check_bytes == 'CR'
  end
end
