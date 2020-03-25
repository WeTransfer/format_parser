
# MPEG Headers documentation:
# http://dvd.sourceforge.net/dvdinfo/mpeghdrs.html#seq
# http://www.cs.columbia.edu/~delbert/docs/Dueck%20--%20MPEG-2%20Video%20Transcoding.pdf
# Useful tool to check the file information: https://www.metadata2go.com/
class FormatParser::MPEGParser
  include FormatParser::IOUtils

  MPEG_VALUES = {
    'mpg' => :mpg,
    'mpeg' => :mpeg
  }

  ASPECT_RATIOS = {
    1 => '1:1',
    2 => '4:3',
    3 => '16:9',
    4 => '2.21:1'
  }

  FRAME_RATES = {
    1 => '23.976',
    2 => '24',
    3 => '25',
    4 => '29.97',
    5 => '30',
    6 => '50',
    7 => '59.94',
    8 => '60'
  }

  PACK_HEADER_START_CODE = "000001ba".freeze
  SEQUENCE_HEADER_START_CODE = "b3".freeze

  def likely_match?(filename)
    filename =~ /\.(mpg|mpeg)$/i
  end

  def call(io)
    return unless matches_mpeg_header?(io)
    
    # We are looping though the stream because there can be several sequence headers and some of them are not usefull. 
    # If we detect that the header is not usefull, then we look for the next one
    # If we reach the EOF, then the mpg is likely to be corrupted and we return nil
    loop do
      search_for_next_sequence_header(io)
      horizontal_size, vertical_size = parse_image_size(io)
      radio_hex, rate_hex = parse_rate_information(io)
      
      if valid_aspect_radio?(radio_hex) && valid_frame_rate?(rate_hex)
        return file_info(horizontal_size, vertical_size, radio_hex, rate_hex) 
      end
    end
  rescue FormatParser::IOUtils::InvalidRead
    nil
  end

  def file_info(width_px, height_px, radio_hex_raw, rate_hex_raw)
    FormatParser::Video.new(
      format: :mpg,
      width_px: width_px,
      height_px: height_px,
      intrinsics: {
        aspect_radio: ASPECT_RATIOS.fetch(radio_hex_raw),
        frame_rate: FRAME_RATES.fetch(rate_hex_raw)
      },
    )
  end

  # The following 3 bytes after the sequence header code, gives us information about the px size
  # 1.5 bytes (12 bits) for horizontal size and 1.5 bytes for vertical size
  def parse_image_size(io)
    image_size = to_hex(safe_read(io, 3))
    return to_decimal(image_size[0..2]), to_decimal(image_size[3..5])
  end

  # The following byte gives us information about the aspect ratio and frame rate
  # 4 bits corresponds to the aspect ratio and 4 bits to the frame rate code
  def parse_rate_information(io)
    rate_information = to_hex(safe_read(io, 1))
    return rate_information[0].to_i, rate_information[1].to_i
  end

  def valid_aspect_radio?(radio)
    ASPECT_RATIOS.include?(radio)
  end

  def valid_frame_rate?(rate)
    FRAME_RATES.include?(rate)
  end

  ## Searches for the next SEQUENCE_HEADER_START_CODE code, which is the code for a sequence header
  ## After this code, comes usefull information about the video
  def search_for_next_sequence_header(io)
    loop do
      break if to_hex(safe_read(io, 1)) == SEQUENCE_HEADER_START_CODE
    end
  end

  ## If the first 4 bytes of the stream are equal to 00 00 01 BA, the pack start code for the Pack Header, then it's an MPEG file.
  def matches_mpeg_header?(io)
    to_hex(safe_read(io, 4)) == PACK_HEADER_START_CODE
  end

  # Unpacks a whole stream to a unique hexadecimal value
  def to_hex(value)
    value.unpack("H*").first
  end

  def to_decimal(value)
    value.to_i(16)
  end

  FormatParser.register_parser new, natures: [:video], formats: MPEG_VALUES.values
end
