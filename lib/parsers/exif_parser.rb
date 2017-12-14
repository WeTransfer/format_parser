require 'exifr/jpeg'

class FormatParser::EXIFParser
  include FormatParser::IOUtils

  # Squash exifr's invalid date warning since we do not use that data.
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
    # Without the magic bytes EXIFR throws an error
    @exif_data.rewind
    EXIFR::JPEG.new(@exif_data)
  end
  
  def scan_tiff
    @exif_data.rewind
    EXIFR::TIFF.new(@exif_data)
  end

end
