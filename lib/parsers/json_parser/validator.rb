class FormatParser::JSONParser::Validator

  MAX_TOKEN_SIZE = 30 # much larger then necessary.

  # states: :awaiting_root_node, :awaiting_attribute_value, :awaiting_attribute_key, :awaiting_array_value, :closed
  #         :reading_token, :reading_string
  # node types: :root, :array, :object, :string, :number, :boolean
  def initialize(io)
    @io = io
    # node types: :array, :object, :string, :number, :boolean
    @parent_nodes = []
    @current_node = nil
    # states: :awaiting_root_node, :awaiting_attribute_value, :awaiting_attribute_key, :awaiting_array_value, :closed
    #         :reading_token, :reading_string
    @current_state = :awaiting_root_node
    @escape_next = []
    @root_closed = false
    @current_token_size = 0
    @pos = 0 # todo: increment properly
  end

  def validate
    char_reader = FormatParser::UTF8Reader.new(@io)

    while (c = char_reader.read_char)
      @pos += 1
      debug "#{@pos}: #{c}\t\t state: #{@current_state} \t\t current: #{@current_node} "
      parse_char c
    end

    # validate encoding
    # limit: 4k?

    # types:
    #   - object
    #   - array
    #   - string (double quotes and escape chars)
    #   - number (positive and negative integers, floats, "." and "," power 10. )
    #   - boolean
    #   - null, undefined, NaN infinity
  end

  private

  def parse_char(c)
    case @current_state
    when :awaiting_root_node # Root node not reached
      parse_when_awaiting_root(c)
    when :awaiting_object_attribute_key
      parse_when_awaiting_object_attribute_key(c)
    when :reading_object_attribute_key
      parse_when_reading_object_attribute_key(c)
    when :awaiting_object_colon_separator
      parse_when_awaiting_object_colon_separator(c)
    when :awaiting_object_attribute_value
      parse_when_awaiting_object_attribute_value(c)
    when :awaiting_array_value
      parse_when_awaiting_array_value(c)
    when :reading_string
      parse_when_reading_string(c, :awaiting_next_entry)
    when :awaiting_next_entry # for both array entry or object attribute
      parse_when_awaiting_next_entry(c)
    when :reading_token
      parse_when_reading_token(c)
    when :closed
      parse_when_closed(c)
    else
      # todo: raise exception?
      reject_char (c)
    end
  end

  # todo: make these parsers use procs and a dynamic map
  # todo: maybe reject_char should be called in a single place
  # todo: maybe rename "handle" as "detect"

  def parse_when_awaiting_root(c)
    return if is_whitespace(c)
    reject_char(c) unless handle_object_start(c) or handle_array_start(c)
  end

  def parse_when_awaiting_object_attribute_key(c)
    return if is_whitespace(c)
    reject_char(c) unless handle_string_start(c, :reading_object_attribute_key)
  end

  def parse_when_reading_object_attribute_key(c)
    parse_when_reading_string(c, :awaiting_object_colon_separator)
  end

  def parse_when_reading_string(c, state_after_close)
    # todo: should not accept unescaped line breaks
    # todo: should handle escaped chars

    reject_char(c) unless handle_string_end(c, state_after_close) or handle_string_content_char(c)
  end

  def parse_when_awaiting_object_colon_separator(c)
    return if is_whitespace(c)
    reject_char(c) unless c == ":"
    @current_state = :awaiting_object_attribute_value
  end

  def parse_when_awaiting_object_attribute_value(c)
    return if is_whitespace(c)
    reject_char(c) unless handle_object_start(c) or handle_array_start(c) or handle_string_start(c) or handle_token_start(c)
  end

  def parse_when_awaiting_array_value(c)
    return if is_whitespace(c)
    reject_char(c) unless handle_object_start(c) or handle_array_start(c) or handle_string_start(c) or handle_token_start(c)
  end

  def parse_when_awaiting_next_entry(c)
    return if is_whitespace(c)

    reject_char(c) unless handle_comma_separator(c) or handle_object_close(c) or handle_array_close(c)
  end

  def parse_when_closed(c)
    return if is_whitespace(c)
    reject_char(c)
  end

  def handle_string_content_char(c)
    # todo
    # any char except quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).
    true
  end

  def is_whitespace(c)
    # todo: add all types and make this UTF8
    c == " " or c == "\t" or c == "\n" or c == "\r"
  end

  def is_valid_token_char(c)
    # todo: bring this outside
    pattern = /\w|[\+\-\.]/ # numbers, letters, +, -, periods
    pattern === c
  end

  def handle_comma_separator(c)
    if c == ","
      if @current_node == :object
        @current_state = :awaiting_object_attribute_key
        return true
      end
      if @current_node == :array
        @current_state = :awaiting_array_value
        return true
      end

      raise "Unexpected configuration."
    end

    false
  end

  # Object: {"k1":"val", "k2":[1,2,3], "k4": undefined, "k5": {"l1": 6}}
  def handle_object_start(c)
    return false if is_whitespace(c)
    return false unless c == "{"

    start_node(:object)
    @current_state = :awaiting_object_attribute_key
    true
  end

  def handle_object_close(c)
    return false if is_whitespace(c)
    return false unless @current_node == :object and c == "}"

    close_node
    @current_state = :awaiting_next_entry
    true
  end

  # Array: [1, "two", true, undefined, {}, []]
  def handle_array_start(c)
    return false unless c == "["

    start_node(:array)
    @current_state = :awaiting_array_value
    true
  end

  def handle_array_close(c)
    return false if is_whitespace(c)
    return false unless @current_node == :array and c == "]"

    close_node
    @current_state = :awaiting_next_entry
    true
  end

  # Strings: "Foo"
  def handle_string_start(c, next_state = :reading_string)
    return false unless c == "\""

    start_node(:string)
    @current_state = next_state
    true
  end

  def handle_string_end(c, state_after_close)
    return false unless c == "\""
    close_node
    @current_state = state_after_close
    true
  end

  # Tokens: null, undefined, true, false, NaN, infinity, -123.456e10 -123,456e10
  def handle_token_start(c)
    return false unless is_valid_token_char(c)

    start_node(:token)
    @current_state = :reading_token
    @current_token_size = 1
    true
  end

  def handle_token_end(c)
    return false if @current_node != :token

    if is_whitespace(c) or c == "," or c == "]" or c == "}"
      close_node
      @current_state = :awaiting_next_entry
      return true
    end

    false
  end

  def parse_when_reading_token(c)
    raise "Token to large at #{@pos}" if @current_token_size > MAX_TOKEN_SIZE
    if is_valid_token_char(c)
      @current_token_size += 1
      return
    end

    handle_token_end(c)
    reject_char(c) unless is_whitespace(c) or handle_comma_separator(c) or handle_array_close(c) or handle_object_close(c)
  end

  def start_node(node_type)
    debug "start: #{node_type}"
    # node types: :array, :object, :string, :number, :boolean
    @parent_nodes.push(@current_node)
    @current_node = node_type
    # states: :awaiting_root_node, :awaiting_attribute_value, :awaiting_attribute_key, :awaiting_array_value, :closed
    #         :reading_token, :reading_string
    @current_state = :awaiting_root_node
  end

  def close_node
    debug "close: #{@current_node}"
    @current_node = @parent_nodes.pop
    @current_state = :closed if @current_node.nil?
  end

  def reject_char(char)
    raise "Unexpected char #{char} in position #{@pos}"
  end


  def debug(msg)
    puts msg
  end
  # extend self
end
