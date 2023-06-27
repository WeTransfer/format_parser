##
# This class checks whether a given file is a valid JSON file.
# The validation process DOES NOT assemble an object with the contents of the JSON file in memory,
# Instead, it implements a simple state-machine-like that digests the contents of the file while traversing
# the hierarchy of nodes in the document.
#
# Although this is based on the IETF standard (https://www.rfc-editor.org/rfc/rfc8259),
# it does cut a few corners for the sake of simplicity. For instance, instead of validating
# Numbers, "true", "false" and "null" tokens, it supports a type called Literal to hold generic sequences of characters.
# This decision makes the implementation simpler while being a good-enough approach to identify JSON files.
#
# There is also a cap. Large files are not read all the way through. Instead, if the beginning of file is
# JSON-compliant, it is assumed that the file is a JSON file.

class FormatParser::JSONParser::Validator
  class JSONParserError < StandardError
  end

  MAX_SAMPLE_SIZE = 1024
  MAX_LITERAL_SIZE = 30 # much larger then necessary.
  ESCAPE_CHAR = "\\"
  WHITESPACE_CHARS = [" ", "\t", "\n", "\r"]
  ENDING_VALUE_CHARS = [",", "]", "}"]
  LITERALS_CHAR_TEMPLATE = /\w|[+\-.]/ # any alphanumeric, "+", "-" and "."

  def initialize(io)
    @io = io
    @current_node = nil # :object, :array, :string, :literal
    @parent_nodes = []
    @current_state = :awaiting_root_node
    @escape_next = false
    @current_literal_size = 0
    @pos = 0

    @all_parsers = {}

    @execution_stats = {
      array: 0,
      object: 0,
      literal: 0,
      string: 0
    }

    setup_transitions
  end

  def validate
    char_reader = FormatParser::UTF8Reader.new(@io)

    while (c = char_reader.read_char)
      @pos += 1
      parse_char c

      # Halt validation if the sampling limit is reached.
      if @pos >= MAX_SAMPLE_SIZE
        raise JSONParserError, "Invalid JSON file" if @current_state == :awaiting_root_node
        return false
      end
    end

    # Raising error in case the EOF is reached earlier than expected
    raise JSONParserError, "Incomplete JSON file" if @current_state != :closed
    true
  rescue  FormatParser::UTF8Reader::UTF8CharReaderError
    raise JSONParserError, "Invalid UTF-8 character"
  end

  def stats(node_type)
    @execution_stats[node_type]
  end

  private

  def setup_transitions
    when_its :awaiting_root_node, ->(c) do
      read_whitespace(c) or
        start_object(c) or
        start_array(c)
    end

    when_its :awaiting_object_attribute_key, ->(c) do
      read_whitespace(c) or
        start_attribute_key(c) or
        close_object(c)
    end

    when_its :reading_object_attribute_key, ->(c) do
      close_attribute_key(c) or
        read_valid_string_char(c)
    end

    when_its :awaiting_object_colon_separator, ->(c) do
      read_whitespace(c) or
        read_colon(c)
    end

    when_its :awaiting_object_attribute_value, ->(c) do
      read_whitespace(c) or
        start_object(c) or
        start_array(c) or
        start_string(c) or
        start_literal(c)
    end

    when_its :awaiting_array_value, ->(c) do
      read_whitespace(c) or
        start_object(c) or
        start_array(c) or
        start_string(c) or
        start_literal(c) or
        close_array(c)
    end

    when_its :reading_string, ->(c) do
      close_string(c) or
        read_valid_string_char(c)
    end

    when_its :awaiting_next_or_close, ->(c) do
      read_whitespace(c) or
        read_comma_separator(c) or
        close_object(c) or
        close_array(c)
    end

    when_its :reading_literal, ->(c) do
      read_valid_literal_char(c) or (
        close_literal(c) and (
          read_whitespace(c) or
          read_comma_separator(c) or
          close_array(c) or
          close_object(c)))
    end

    when_its :closed, ->(c) do
      read_whitespace(c)
    end
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
      @escape_next = false
      return true
    end

    if c == ESCAPE_CHAR
      @escape_next = true
      return true
    end
    !control_char?(c) and c != "\""
  end

  def read_valid_literal_char(c)
    if valid_literal_char?(c)
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

    begin_node(:object)
    @current_state = :awaiting_object_attribute_key
    true
  end

  def close_object(c)
    return false if whitespace?(c)
    return false unless @current_node == :object and c == "}"

    end_node
    @current_state = :awaiting_next_or_close unless @current_node.nil?
    true
  end

  # Array: [1, "two", true, undefined, {}, []]
  def start_array(c)
    return false unless c == "["

    begin_node(:array)
    @current_state = :awaiting_array_value
    true
  end

  def close_array(c)
    return false if whitespace?(c)
    return false unless @current_node == :array and c == "]"

    end_node
    @current_state = :awaiting_next_or_close unless @current_node.nil?
    true
  end

  def start_attribute_key(c)
    return false unless c == "\""

    begin_node(:string)
    @current_state = :reading_object_attribute_key
    true
  end

  def close_attribute_key(c)
    return false if @escape_next
    return false unless c == "\""
    end_node
    @current_state = :awaiting_object_colon_separator
    true
  end

  # Strings: "Foo"
  def start_string(c)
    return false unless c == "\""

    begin_node(:string)
    @current_state = :reading_string
    true
  end

  def close_string(c)
    return false if @escape_next
    return false unless c == "\""
    end_node
    @current_state = :awaiting_next_or_close
    true
  end

  # literals: null, undefined, true, false, NaN, infinity, -123.456e10 -123,456e10
  def start_literal(c)
    return false unless valid_literal_char?(c)

    begin_node(:literal)
    @current_state = :reading_literal
    @current_literal_size = 1
    true
  end

  def close_literal(c)
    raise JSONParserError, "Literal to large at #{@pos}" if @current_literal_size > MAX_LITERAL_SIZE

    if whitespace?(c) || ENDING_VALUE_CHARS.include?(c)
      end_node
      @current_state = :awaiting_next_or_close
      return true
    end

    false
  end

  # Marks the creation of a node (object, array, string or literal)
  def begin_node(node_type)
    # Accounting for the new node
    @execution_stats[node_type] ||= 0
    @execution_stats[node_type] += 1

    # Managing the node execution stack
    @parent_nodes.push(@current_node)
    @current_node = node_type
  end

  # Marks the closure of a node (object, array, string or literal)
  def end_node
    @current_node = @parent_nodes.pop
    @current_state = :closed if @current_node.nil?
  end

  def reject_char(char)
    raise JSONParserError, "Unexpected char #{char} in position #{@pos}"
  end

  def whitespace?(c)
    WHITESPACE_CHARS.include?(c)
  end

  def control_char?(c)
    # control characters: (U+0000 through U+001F)
    utf8_code = c.unpack('U*')[0]
    utf8_code <= 31
  end

  def valid_literal_char?(c)
    LITERALS_CHAR_TEMPLATE === c
  end
end
