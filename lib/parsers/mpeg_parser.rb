
# MPEG Headers documentation:
# http://dvd.sourceforge.net/dvdinfo/mpeghdrs.html#seq
# http://www.cs.columbia.edu/~delbert/docs/Dueck%20--%20MPEG-2%20Video%20Transcoding.pdf
# Useful tool to check the file information: https://www.metadata2go.com/
class FormatParser::MPEGParser
  extend FormatParser::IOUtils

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

  PACK_HEADER_START_CODE = [0x00, 0x00, 0x01, 0xBA].pack('C*')
  SEQUENCE_HEADER_START_CODE = [0xB3].pack('C*')
  MAX_BLOCK_READS = 32
  BYTES_TO_READ_PER_READ = 1024

  def self.likely_match?(filename)
    filename =~ /\.(mpg|mpeg)$/i
  end

  def self.call(io)
    return unless matches_mpeg_header?(io)

    # We are looping though the stream because there can be several sequence headers and some of them are not useful.
    # If we detect that the header is not useful, then we look for the next one for SEEK_FOR_SEQUENCE_HEADER_TIMES_LIMIT
    # If we reach the EOF, then the mpg is likely to be corrupted and we return nil
    MAX_BLOCK_READS.times do
      next unless pos = find_next_header_code_pos(io)
      io.seek(pos + 1)
      horizontal_size, vertical_size = parse_image_size(io)
      ratio_code, rate_code = parse_rate_information(io)
      return file_info(horizontal_size, vertical_size, ratio_code, rate_code) if valid_aspect_ratio_code?(ratio_code) && valid_frame_rate_code?(rate_code)
    end
    nil # otherwise the return value of Integer#times will be returned
  rescue FormatParser::IOUtils::InvalidRead
    nil
  end

  def self.file_info(width_px, height_px, ratio_code, rate_code)
    FormatParser::Video.new(
      format: :mpg,
      width_px: width_px,
      height_px: height_px,
      intrinsics: {
        aspect_ratio: ASPECT_RATIOS.fetch(ratio_code),
        frame_rate: FRAME_RATES.fetch(rate_code)
      },
    )
  end

  # The following 3 bytes after the sequence header code, gives us information about the px size
  # 1.5 bytes (12 bits) for horizontal size and 1.5 bytes for vertical size
  def self.parse_image_size(io)
    image_size = convert_3_bytes_to_bits(safe_read(io, 3))
    [read_first_12_bits(image_size), read_last_12_bits(image_size)]
  end

  # The following byte gives us information about the aspect ratio and frame rate
  # 4 bits corresponds to the aspect ratio and 4 bits to the frame rate code
  def self.parse_rate_information(io)
    rate_information = safe_read(io, 1).unpack('C').first
    [read_first_4_bits(rate_information), read_last_4_bits(rate_information)]
  end

  def self.valid_aspect_ratio_code?(ratio_code)
    ASPECT_RATIOS.include?(ratio_code)
  end

  def self.valid_frame_rate_code?(rate_code)
    FRAME_RATES.include?(rate_code)
  end

  # Returns the position of the next sequence package content in the stream
  # This method will read BYTES_TO_READ_PER_TIME in each loop for a maximum amount of SEEK_FOR_SEQUENCE_HEADER_START_CODE_TIMES_LIMIT times
  # If the package is not found, then it returns nil.
  def self.find_next_header_code_pos(io)
    pos_before_read = io.pos
    bin_str = io.read(BYTES_TO_READ_PER_READ) # bin_str might be nil if we are at EOF
    header_relative_index = bin_str && bin_str.index(SEQUENCE_HEADER_START_CODE)
    return pos_before_read + header_relative_index if header_relative_index
  end

  # If the first 4 bytes of the stream are equal to 00 00 01 BA, the pack start code for the Pack Header, then it's an MPEG file.
  def self.matches_mpeg_header?(io)
    safe_read(io, 4) == PACK_HEADER_START_CODE
  end

  def self.convert_3_bytes_to_bits(bytes)
    bytes = bytes.unpack('CCC')
    (bytes[0] << 16) | (bytes[1] << 8) | (bytes[2])
  end

  def self.read_first_12_bits(bits)
    bits >> 12 & 0x0fff
  end

  def self.read_last_12_bits(bits)
    bits & 0x0fff
  end

  def self.read_first_4_bits(byte)
    byte >> 4
  end

  def self.read_last_4_bits(byte)
    byte & 0x0F
  end

  FormatParser.register_parser self, natures: [:video], formats: [:mpg, :mpeg]
end
