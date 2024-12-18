##
# This class Reads individual characters from files using UTF-8 encoding
# This deals with two main concerns:
#   - Variable byte length of characters
#   - Reducing the number of read operations by loading bytes in chunks

class FormatParser::UTF8Reader
  READ_CHUNK_SIZE = 128

  class UTF8CharReaderError < StandardError
  end

  def initialize(io)
    @io = io
    @chunk = ""
    @index = 0
    @eof = false
  end

  def read_char
    first_byte = read_byte
    return if first_byte.nil?

    char_length = assess_char_length(first_byte)
    as_bytes = Array.new(char_length) do |i|
      next first_byte if i == 0
      read_byte
    end

    char = as_bytes.pack('c*').force_encoding('UTF-8')
    raise UTF8CharReaderError, "Invalid UTF-8 character" unless char.valid_encoding?

    char
  rescue TypeError
    raise UTF8CharReaderError, "Invalid UTF-8 character"
  end

  private

  def read_byte
    manage_data_chunk
    return if @chunk.nil?
    byte = @chunk.bytes[@index]
    @index += 1 unless byte.nil?
    byte
  end

  def manage_data_chunk
    return if @index < @chunk.length
    @chunk = @io.read(READ_CHUNK_SIZE)
    @chunk ||= ""
    @index = 0
    @eof = true if @chunk.nil? or @chunk.length < READ_CHUNK_SIZE
  end

  def assess_char_length(first_byte)
    # 0_______ (1 byte)
    # 110_____ (2 bytes) 192
    # 1110____ (3 bytes) 224
    # 11110___ (4 bytes) 240
    case first_byte
    when 240.. then 4
    when 224..239 then 3
    when 192..223 then 2
    else 1
    end
  end
end
