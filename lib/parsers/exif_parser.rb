require 'exifr/tiff'
require 'delegate'

module FormatParser::EXIFParser
  ORIENTATIONS = {
    0 => :unknown, # Non-rotated
    1 => :top_left, # Non-rotated
    2 => :top_right, # Non-rotated
    3 => :bottom_right, # Non-rotated
    4 => :bottom_left, # Non-rotated
    5 => :left_top,
    6 => :right_top,
    7 => :right_bottom,
    8 => :left_bottom
  }

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

  class EXIFResult < SimpleDelegator
    def rotated?
      __getobj__.orientation.to_i > 4
    end

    def to_json(*maybe_coder)
      hash_representation = __getobj__.to_hash
      sanitized = FormatParser::AttributesJSON._sanitize_json_value(hash_representation)
      sanitized.to_json(*maybe_coder)
    end

    def orientation
      value = __getobj__.orientation.to_i
      ORIENTATIONS.fetch(value)
    end
  end

  # Squash exifr's invalid date warning since we do not use that data.
  EXIFR.logger = Logger.new(nil)

  def exif_from_tiff_io(constrained_io)
    Measurometer.instrument('format_parser.EXIFParser.exif_from_tiff_io') do
      raw_exif_data = EXIFR::TIFF.new(IOExt.new(constrained_io))
      raw_exif_data ? EXIFResult.new(raw_exif_data) : nil
    end
  end
end
