# todo: Add a description of what this validator does
#   types:
#   - object
#   - array
#   - string (double quotes and escape chars)
#   - Literal (numbers, booleans and keywords like null, undefined, etc.)
class FormatParser::JSONParser::Validator

  class JSONParserError < StandardError
  end
  # validate encoding
  # limit: 4k?

  MAX_LITERAL_SIZE = 30 # much larger then necessary.
  ESCAPE_CHAR = "\\"
  LITERALS_CHAR_TEMPLATE = /\w|[+\-.]/ # alphanumerics, "+", "-" and "."

  def initialize(io)
    @io = io
    # node types: :array, :object, :string, :literal
    @parent_nodes = []
    @current_node = nil
    @current_state = :awaiting_root_node
    @escape_next = false
    @current_literal_size = 0
    @pos = 0

    @all_parsers = {}

    setup_transitions
  end

  def validate
    char_reader = FormatParser::UTF8Reader.new(@io)

    while (c = char_reader.read_char)
      @pos += 1
      debug "#{@pos}: #{c}\t\t state: #{@current_state} \t\t current: #{@current_node} "
      parse_char c
    end

    puts "Final node is: #{@current_node}"
    puts "Final state is: #{@current_state}"
    raise JSONParserError, "Incomplete JSON file" if @current_state != :closed
  end

  private

  def setup_transitions
    when_its :awaiting_root_node, ->(c) {
      read_whitespace(c) or
        start_object(c) or
        start_array(c)
    }

    when_its :awaiting_object_attribute_key, ->(c) {
      read_whitespace(c) or
        start_attribute_key(c)
    }

    when_its :reading_object_attribute_key, ->(c) {
      close_attribute_key(c) or
        read_valid_string_char(c)
    }

    when_its :awaiting_object_colon_separator, ->(c) {
      read_whitespace(c) or
        read_colon(c)
    }

    when_its :awaiting_object_attribute_value, ->(c) {
      read_whitespace(c) or
        start_object(c) or
        start_array(c) or
        start_string(c) or
        start_literal(c)
    }

    when_its :awaiting_array_value, ->(c) {
      read_whitespace(c) or
        start_object(c) or
        start_array(c) or
        start_string(c) or
        start_literal(c)
    }

    when_its :reading_string, ->(c) {
      close_string(c) or
        read_valid_string_char(c)
    }

    when_its :awaiting_next_or_close, ->(c) {
      read_whitespace(c) or
        read_comma_separator(c) or
        close_object(c) or
        close_array(c)
    }

    #todo: remove detects
    when_its :reading_literal, ->(c) {
      detect_valid_literal_char(c) or (
        detect_literal_end(c) and (
          read_whitespace(c) or
          read_comma_separator(c) or
          close_array(c) or
          close_object(c)))
    }

    when_its :closed, ->(c) {
      read_whitespace(c)
    }
  end

  def when_its(state, act)
    @all_parsers[state] = act
  end

  def parse_char(c)
    next_step = @all_parsers[@current_state]
    accepted = next_step.call(c)
    reject_char(c) unless accepted
  end

  def read_whitespace(c)
    whitespace?(c)
  end

  def read_colon(c)
    if c == ":"
      @current_state = :awaiting_object_attribute_value
      return true
    end
    false
  end

  def read_valid_string_char(c)
    if @escape_next
      puts "escaped: #{c}"
      @escape_next = false
      return true
    end

    if c == ESCAPE_CHAR
      @escape_next = true
      puts "escaping next char"
      return true
    end
    !control_char?(c) and c != "\""
  end

  def detect_valid_literal_char(c)
    if LITERALS_CHAR_TEMPLATE === c
      @current_literal_size += 1
      return true
    end

    false
  end

  def read_comma_separator(c)
    if c == ","
      @current_state = :awaiting_object_attribute_key if @current_node == :object
      @current_state = :awaiting_array_value if @current_node == :array
      return true
    end
    false
  end

  # Object: {"k1":"val", "k2":[1,2,3], "k4": undefined, "k5": {"l1": 6}}
  def start_object(c)
    return false if whitespace?(c)
    return false unless c == "{"

    start_node(:object)
    @current_state = :awaiting_object_attribute_key
    true
  end

  def close_object(c)
    return false if whitespace?(c)
    return false unless @current_node == :object and c == "}"

    close_node
    @current_state = :awaiting_next_or_close unless @current_node.nil?
    true
  end

  # Array: [1, "two", true, undefined, {}, []]
  def start_array(c)
    return false unless c == "["

    start_node(:array)
    @current_state = :awaiting_array_value
    true
  end

  def close_array(c)
    return false if whitespace?(c)
    return false unless @current_node == :array and c == "]"

    close_node
    @current_state = :awaiting_next_or_close unless @current_node.nil?
    true
  end

  def start_attribute_key(c)
    return false unless c == "\""

    start_node(:string)
    @current_state = :reading_object_attribute_key
    true
  end
  def close_attribute_key(c)
    return false if @escape_next
    return false unless c == "\""
    close_node
    @current_state = :awaiting_object_colon_separator
    true
  end

  # Strings: "Foo"
  def start_string(c)
    return false unless c == "\""

    start_node(:string)
    @current_state = :reading_string
    true
  end

  def close_string(c)
    return false if @escape_next
    return false unless c == "\""
    close_node
    @current_state = :awaiting_next_or_close
    true
  end

  # literals: null, undefined, true, false, NaN, infinity, -123.456e10 -123,456e10
  def start_literal(c)
    return false unless detect_valid_literal_char(c)

    start_node(:literal)
    @current_state = :reading_literal
    @current_literal_size = 1
    true
  end

  def detect_literal_end(c)
    return false if @current_node != :literal
    raise JSONParserError, "Literal to large at #{@pos}" if @current_literal_size > MAX_LITERAL_SIZE

    if whitespace?(c) or c == "," or c == "]" or c == "}"
      close_node
      @current_state = :awaiting_next_or_close
      return true
    end

    false
  end

  def start_node(node_type)
    debug "start: #{node_type}"
    @parent_nodes.push(@current_node)
    @current_node = node_type
    @current_state = :awaiting_root_node
  end

  def close_node
    debug "close: #{@current_node}"
    @current_node = @parent_nodes.pop
    @current_state = :closed if @current_node.nil?
  end

  def reject_char(char)
    raise JSONParserError, "Unexpected char #{char} in position #{@pos}"
  end

  def whitespace?(c)
    c == " " or c == "\t" or c == "\n" or c == "\r"
  end

  def control_char?(c)
    # control characters: (U+0000 through U+001F)
    utf8_code = c.unpack('U*')[0]
    utf8_code <= 31
  end

  def debug(msg)
    puts msg
  end
end
