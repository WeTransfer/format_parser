class FormatParser::JSONParser::Validator

  # validate encoding
  # limit: 4k?

  # types:
  #   - object
  #   - array
  #   - string (double quotes and escape chars)
  #   - Literal (numbers, booleans and keywords like null, undefined, etc.)

  MAX_LITERAL_SIZE = 30 # much larger then necessary.

  def initialize(io)
    @io = io
    # node types: :array, :object, :string, :literal
    @parent_nodes = []
    @current_node = nil
    @current_state = :awaiting_root_node
    @escape_next = []
    @root_closed = false
    @current_literal_size = 0
    @pos = 0 # todo: increment properly

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
  end

  private

  def setup_transitions
    when_its :awaiting_root_node, ->(c) {
        is_whitespace(c) or
          detect_object_start(c) or
          detect_array_start(c)
    }

    when_its :awaiting_object_attribute_key, ->(c) {
        is_whitespace(c) or
          detect_string_start(c, :reading_object_attribute_key)
    }

    when_its :reading_object_attribute_key, ->(c) {
      detect_string_end(c, :awaiting_object_colon_separator) or
        detect_string_content_char(c)
    }

    when_its :awaiting_object_colon_separator, ->(c) {
      is_whitespace(c) or
        detect_colon_object_separator(c)
    }

    when_its :awaiting_object_attribute_value, ->(c) {
        is_whitespace(c) or
          detect_object_start(c) or
          detect_array_start(c) or
          detect_string_start(c) or
          detect_literal_start(c)
    }

    when_its :awaiting_array_value, ->(c) {
      is_whitespace(c) or
        detect_object_start(c) or
        detect_array_start(c) or
        detect_string_start(c) or
        detect_literal_start(c)
    }

    when_its :reading_string, ->(c) {
      detect_string_end(c, :awaiting_next_or_close) or
        detect_string_content_char(c)
    }

    when_its :awaiting_next_or_close, ->(c) {
      is_whitespace(c) or
        detect_comma_separator(c) or
        detect_object_close(c) or
        detect_array_close(c)
    }

    when_its :reading_literal, ->(c) {
      detect_valid_literal_char(c) or (
        detect_literal_end(c) and (
          is_whitespace(c) or
          detect_comma_separator(c) or
          detect_array_close(c) or
          detect_object_close(c)))
    }

    when_its :closed, ->(c) {
      is_whitespace(c)
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


  def detect_colon_object_separator(c)
    return false unless @current_state == :awaiting_object_colon_separator
    if c == ":"
      @current_state = :awaiting_object_attribute_value
      return true
    end
    false
  end

  def detect_string_content_char(c)
    # todo
    # any char except quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).
    # todo: should not accept unescaped line breaks
    # todo: should handle escaped chars
    true
  end

  def detect_valid_literal_char(c)
    # todo: bring this pattern outside
    pattern = /\w|[\+\-\.]/ # numbers, letters, +, -, periods

    if pattern === c
      @current_literal_size += 1
      return true
    end

    false
  end

  def detect_comma_separator(c)
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
  def detect_object_start(c)
    return false if is_whitespace(c)
    return false unless c == "{"

    start_node(:object)
    @current_state = :awaiting_object_attribute_key
    true
  end

  def detect_object_close(c)
    return false if is_whitespace(c)
    return false unless @current_node == :object and c == "}"

    close_node
    @current_state = :awaiting_next_or_close
    true
  end

  # Array: [1, "two", true, undefined, {}, []]
  def detect_array_start(c)
    return false unless c == "["

    start_node(:array)
    @current_state = :awaiting_array_value
    true
  end

  def detect_array_close(c)
    return false if is_whitespace(c)
    return false unless @current_node == :array and c == "]"

    close_node
    @current_state = :awaiting_next_or_close
    true
  end

  # Strings: "Foo"
  def detect_string_start(c, next_state = :reading_string)
    return false unless c == "\""

    start_node(:string)
    @current_state = next_state
    true
  end

  def detect_string_end(c, state_after_close)
    return false unless c == "\""
    close_node
    @current_state = state_after_close
    true
  end

  # literals: null, undefined, true, false, NaN, infinity, -123.456e10 -123,456e10
  def detect_literal_start(c)
    return false unless detect_valid_literal_char(c)

    start_node(:literal)
    @current_state = :reading_literal
    @current_literal_size = 1
    true
  end

  def detect_literal_end(c)
    return false if @current_node != :literal

    # todo: should we raise this here?
    raise "Literal to large at #{@pos}" if @current_literal_size > MAX_LITERAL_SIZE

    if is_whitespace(c) or c == "," or c == "]" or c == "}"
      close_node
      @current_state = :awaiting_next_or_close
      return true
    end

    false
  end

  def start_node(node_type)
    debug "start: #{node_type}"
    # node types: :array, :object, :string, :number, :boolean
    @parent_nodes.push(@current_node)
    @current_node = node_type
    # states: :awaiting_root_node, :awaiting_attribute_value, :awaiting_attribute_key, :awaiting_array_value, :closed
    #         :reading_literal, :reading_string
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

  def is_whitespace(c)
    # todo: make this UTF8
    c == " " or c == "\t" or c == "\n" or c == "\r"
  end

  def debug(msg)
    puts msg
  end
  # extend self
end
