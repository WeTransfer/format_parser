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
      orientation.to_i > 4
    end

    def to_json(*maybe_coder)
      hash_representation = __getobj__.to_hash
      sanitized = FormatParser::AttributesJSON._sanitize_json_value(hash_representation)
      sanitized.to_json(*maybe_coder)
    end

    def orientation
      # In some EXIF tags the value type is set oddly - it unpacks into multiple values,
      # and it will look like this: [#<EXIFR::TIFF::Orientation:TopLeft(1)>, nil]
      orientation_values = Array(__getobj__.orientation)
      last_usable_value = orientation_values.compact[-1] # Use the last non-nil one
      last_usable_value.to_i
    end

    def orientation_sym
      ORIENTATIONS.fetch(orientation)
    end
  end

  # With some formats, multiple EXIF tag frames can be included in a single file.
  # For example, JPEGs might have multiple APP1 markers which each contain EXIF
  # data. The EXIF data in them, however, is not necessarily "complete" - it seems
  # most applications assume that these blocks "overwrite" each other with the properties
  # they specify. Probably this is done for more efficient saving - instead of overwriting
  # the EXIF data with a modified version - which would also potentially disturb any digital
  # signing that this data might include - the applications are supposed to follow the order
  # in which these tags appear in the file:
  #
  # Take a resized image for example:
  #
  #   APP1 {author: 'John', pixel_width: 1024}
  #   APP1 {pixel_width: 10}
  #
  # That image would get a combined EXIF of:
  #
  #   APP1 {author: 'John', pixel_width: 10}
  #
  # since the frame that comes later in the file overwrites a property. From what I see
  # exiftools do this is the way it works.
  #
  # This class acts as a wrapper for this "layering" of chunks of EXIF properties, and will
  # follow the following conventions:
  #
  # * When merging data for JSON conversion, it will merge it top-down. It will overwrite
  #   any specified properties. An exception is made for orientation (see below)
  # * When retrieving a property, it will look "from the end to the beginning" of the EXIF
  #   dataframe stack, looking for the first dataframe which has this property with a non-nil value
  # * When retrieving orientation, it will pick the first orientation value which is not nil
  #   but also not 0 ("unknown orientation"). Even files in our test suite contain these.
  class EXIFStack
    def initialize(multiple_exif_results)
      @multiple_exif_results = Array(multiple_exif_results)
    end

    def to_json(*maybe_coder)
      to_hash.to_json(*maybe_coder)
    end

    def orientation_sym
      ORIENTATIONS.fetch(orientation)
    end

    def rotated?
      orientation > 4
    end

    def orientation
      # Retrieving an orientation "through" the sequence of EXIF tags
      # is trickier than the method_missing case, because the value
      # of the orientation can be 0, meaning "unknown". We need to skip through
      # those and return the _last_ non-0 orientation, or 0 otherwise
      @multiple_exif_results.reverse_each do |exif_tag_frame|
        orientation_value = exif_tag_frame.orientation
        if !orientation_value.nil? && orientation_value != 0
          return orientation_value
        end
      end
      0 # If none were found - the orientation is unknown
    end

    # ActiveSupport will attempt to call #to_hash first, and
    # #to_hash is a decent default implementation to have
    def to_hash
      # Let EXIF tags that come later overwrite the properties from the tags
      # that come earlier
      overlay = @multiple_exif_results.each_with_object({}) do |one_exif_frame, h|
        h.merge!(one_exif_frame.to_hash)
      end
      # Overwrite the orientation with our custom method implementation, because
      # it does reject 0-values.
      overlay[:orientation] = orientation

      FormatParser::AttributesJSON._sanitize_json_value(overlay)
    end

    private

    # respond_to_missing? accepts 2 arguments: the method name symbol
    # and whether the method being looked up can be private or not
    def respond_to_missing?(method_name, include_private_methods)
      @multiple_exif_results.last.respond_to?(method_name, include_private_methods)
    end

    def method_missing(*a)
      return super unless @multiple_exif_results.any?

      # The EXIF tags get appended to the file, so the ones coming _later_
      # are more specific and potentially overwrite the earlier ones. Walk
      # through the frames in reverse (starting with one that comes last)
      # and if it contans the requisite EXIF property, return the value
      # from that tag.
      @multiple_exif_results.reverse_each do |exif_tag_frame|
        value_of = exif_tag_frame.public_send(*a)
        return value_of if value_of
      end
      nil
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

  extend self
end
