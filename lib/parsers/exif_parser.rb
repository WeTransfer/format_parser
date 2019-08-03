require 'exifr/tiff'
require 'delegate'

module FormatParser::EXIFParser
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
  ROTATED_ORIENTATIONS = ORIENTATIONS - [
    :bottom_left,
    :bottom_right,
    :top_left,
    :top_right
  ]

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
      ROTATED_ORIENTATIONS.include?(orientation)
    end

    def to_json(*maybe_coder)
      hash_representation = __getobj__.to_hash
      sanitized = FormatParser::AttributesJSON._sanitize_json_value(hash_representation)
      sanitized.to_json(*maybe_coder)
    end

    def orientation
      value = __getobj__.orientation.to_i
      ORIENTATIONS.fetch(value - 1)
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
