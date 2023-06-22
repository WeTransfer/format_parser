# todo: describe this and document methods
class FormatParser::UTF8Reader
  READ_CHUNK_SIZE = 128

  def initialize(io)
    @io = io
    @chunk = []
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

    as_bytes.pack('c*').force_encoding('UTF-8')
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
    @index = 0
    @eof = true if @chunk.nil? or @chunk.length < READ_CHUNK_SIZE
  end

  def assess_char_length(first_byte)
    # 0_______ (1 byte)
    # 110_____ (2 bytes) 192
    # 1110____ (3 bytes) 224
    # 11110___ (4 bytes) 240
    return 4 if first_byte >= 240
    return 3 if first_byte >= 224
    return 2 if first_byte >= 192
    1
  end
end
