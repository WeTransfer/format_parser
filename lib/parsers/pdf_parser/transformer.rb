class FormatParser::PDFParser::Transformer
  class PDFRef < Struct.new(:object_id, :object_gen)
    def self.from_ref_str(str)
      id_and_generation_str = str.scan(/(\d+) (\d+) R/).first
      new(*id_and_generation_str.map(&:to_i))
    end
  end

  class PDFName < Struct.new(:name)
  end

  # Permitted character escapes. There aren't _that_ many so we can use a table
  STRING_ESCAPES = {
    "\r"   => "\n",
    "\n\r" => "\n",
    "\r\n" => "\n",
    '\\n'  => "\n",
    '\\r'  => "\r",
    '\\t'  => "\t",
    '\\b'  => "\b",
    '\\f'  => "\f",
    '\\('  => '(',
    '\\)'  => ')',
    '\\\\' => '\\',
    "\\\n" => '',
  }

  # Octal character escapes that look like \001 etc
  0.upto(9)   { |n| STRING_ESCAPES['\\00' + n.to_s] = ('00' + n.to_s).oct.chr }
  0.upto(99)  { |n| STRING_ESCAPES['\\0' + n.to_s]  = ('0' + n.to_s).oct.chr }
  0.upto(377) { |n| STRING_ESCAPES['\\' + n.to_s]   = n.to_s.oct.chr }

  LITERAL_VALUES = {
    :true => true,
    :false => false,
    :null => nil,
  }

  def transform(tokens)
    tokens.map {|t| unwrap(*t) }
  end

  def unwrap(token_type, token_value)
    case token_type
    when :dict
      unwrap_dict(token_value)
    when :array
      unwrap_array(token_value)
    when :real
      unwrap_real(token_value)
    when :int
      unwrap_int(token_value)
    when :ref
      unwrap_ref(token_value)
    when :name
      unwrap_name(token_value)
    when :lit
      unwrap_lit(token_value)
    else
      token_value
    end
  end

  def unwrap_real(value)
    value.to_f
  end

  def unwrap_int(value)
    value.to_i
  end

  def unwrap_dict(value)
    unwrapped_values = value.map{|e| unwrap(*e) }
    keys, values = unwrapped_values.partition.with_index {|_, i| i % 2 == 0 }
    Hash[keys.zip(values)]
  end

  def unwrap_lit(value)
    LITERAL_VALUES.fetch(value, value.to_sym)
  end

  def unwrap_ref(value)
    PDFRef.from_ref_str(value)
  end

  def unwrap_array(value)
    value.map {|e| unwrap(*e) }
  end

  def unwrap_hex_string(str)
    str << '0' unless str.bytesize.even?
    str.scan(/../).map { |i| i.hex.chr }.join
  end

  def unwrap_string(str)
    str.gsub(/\\([nrtbf()\\\n]|\d{1,3})?|\r\n?|\n\r/m) do |match|
      STRING_ESCAPES[match] || ''
    end
  end

  def unwrap_name(name)
    # Replace #0xx hex codes with the corresponding chars
    name_sans_escapes = name.gsub(/\#([\da-fA-F]{1,2})/) do |_hex_code|
      $1.to_i(16).chr
    end
  end
end
