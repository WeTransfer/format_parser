require 'exifr/jpeg'

class FormatParser::EXIFParser
  include FormatParser::IOUtils

  # Squash exifr's invalid date warning since we disgard that data.
  logger = Logger.new(STDERR)
  logger.level = Logger::FATAL
  EXIFR.logger = logger


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

end
