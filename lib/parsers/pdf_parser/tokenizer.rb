class FormatParser::PDFParser::Tokenizer
  Malformed = Class.new(RuntimeError)
  RE = ->(str) { /#{Regexp.escape(str)}/ }

  NAME_RE = begin
    # The ASCII subset permissible for PDF name values
    printable_ascii = (32..126).to_a
    printable_ascii.delete(' '.ord)
    printable_ascii.delete('['.ord)
    printable_ascii.delete(']'.ord)
    printable_ascii.delete('<'.ord)
    printable_ascii.delete('>'.ord)
    printable_ascii.delete('('.ord)
    printable_ascii.delete(')'.ord)
    printable_ascii.delete('/'.ord)
    printable_ascii.delete('\\'.ord)
    exact_char_class = printable_ascii.map(&:chr).join

    /\/[#{exact_char_class}]{0,}/
  end

  STRATEGIES = {
    RE['<<'] => :parse_dictionary,
    RE['[']  => :parse_array,
    RE['(']  => :parse_string,
    /<[0-9a-f]+>/i  => :parse_hex_string,
    /\d+ \d+ R/ => :parse_ref,
    NAME_RE => :parse_pdf_name,

    RE['true']  => :wrap_lit,
    RE['false'] => :wrap_lit,
    RE['null']  => :wrap_lit,

    # 34.5 −3.62 +123.6 4. −.002 0.0 are all valid reals
    /(\-|\+?)(\d+)\.(\d+)/ => :wrap_real,
    /(\-|\+?)(\d+)\./ => :wrap_real,
    /(\-|\+?)\.(\d+)/ => :wrap_real,
    /\-?(\d+)/ => :wrap_int,

    RE['obj']       => :wrap_lit,
    # Use dirty trick to stop parsing if we encounter anything binary. This does not
    # prevent us from reading ahead into the stream, but it does allow is to abort
    # quicker
    RE['endobj']    => :abort,
    RE['stream']    => :abort,
    RE['endstream'] => :abort,

    /\s+/           => :wrap_whitespace,
    /./             => :garbage,
  }

  def wrap_real(pattern)
    [:real, @sc.scan(pattern)]
  end

  def wrap_int(pattern)
    [:int, @sc.scan(pattern)]
  end

  def wrap_whitespace(pattern)
    @sc.scan(pattern)
    [:whitespace, nil]
  end

  def wrap_lit(pattern)
    [:lit, @sc.scan(pattern).to_sym]
  end

  def consume!(pattern, method_name)
    at = @sc.pos
    return false unless @sc.check(pattern)
    debug { "M: #{method_name} @#{at}: 8 chars after scan pointer #{@sc.peek(8).inspect}" }
    result = send(method_name, pattern)
    @token_stream << result unless result == [:whitespace, nil]
    true
  end

  def parse_ref(start_pattern)
    [:ref, @sc.scan(start_pattern)]
  end

  def parse_array(start_pattern)
    @sc.scan(start_pattern) # consume [
    dict_open_at = @token_stream.length
    walk_scanner(RE[']'])
    raise Malformed, 'Array did not terminate' unless @token_stream.pop == :terminator
    array_items = @token_stream.pop(@token_stream.length - dict_open_at)
    [:array, array_items]
  end

  def parse_dictionary(start_pattern)
    @sc.scan(start_pattern) # consume <<
    dict_open_at = @token_stream.length
    walk_scanner(RE['>>'])
    raise Malformed, 'Dictionary did not terminate' unless @token_stream.pop == :terminator
    dict_items = @token_stream.pop(@token_stream.length - dict_open_at)
    [:dict, dict_items]
  end

  def parse_hex_string(start_pattern)
    [:hex_string, @sc.scan(start_pattern)]
  end

  def parse_string(opening_brace_pattern)
    # This is murder. PDF allows paired braces to be put into a string literal
    # without any escaping. This means that "(Horrible file format (with a cherry on top))"
    # is a valid string. Needs attention.
    @sc.scan(opening_brace_pattern) # just the "("
    str = ""
    count = 1
    bytes_remaining_to_scan.times do
      # Terminate if EOS reached or once we encountered the outermost closing brace
      break if @sc.eos? || count == 0

      byte = @sc.scan(/./)
      if byte.nil?
        count = 0 # unbalanced parens
      elsif byte == 0x5C.chr # "\"
        str << byte << @sc.scan(/\./).to_s
      elsif byte == 0x28.chr # "("
        str << "("
        count += 1
      elsif byte == 0x29.chr # ")"
        count -= 1
        str << ")" unless count == 0
      else
        str << byte unless count == 0
      end
      break if count == 0
    end
    raise Malformed, "String did not terminate at #{@sc.pos}" if count > 0
    [:str, str]
  end

  def parse_pdf_name(start_pattern)
    [:name, @sc.scan(start_pattern)]
  end

  def garbage(*)
    raise Malformed, "Expected a meaningful token at #{@sc.pos} but did not encounter one"
  end

  def bytes_remaining_to_scan
    @sc.string.bytesize - @sc.pos
  end

  def walk_scanner(halt_at_pattern)
    # Limit the iterations to AT MOST (!) once per
    # remaining byte to parse. This ensures we won't
    # have parsing enter an infinite loop where we expect
    # the string scanner to have advanced at least a byte forward
    # but it would sit on the same offset indifinitely.
    bytes_remaining_to_scan.times do
      # Terminate if EOS reached
      break if @sc.eos?

      # Terminate early
      if halt_at_pattern && halted = @sc.scan(halt_at_pattern)
        @token_stream << :terminator
        return
      end

      # Walk through STRATEGIES and stop iterating on first non-false call to consume!
      # STRATEGIES are arranged by order of specificity, so for most iterations
      # somethign meaningful should be hit relatively quickly
      STRATEGIES.find do |pattern, method_name|
        consume!(pattern, method_name)
      end
    end
  end

  # Dirty thing we use to stop parsing as soon as we encounter a "stream", "xstream"
  def abort(pattern)
    str = @sc.scan(pattern)
    debug { "X: Aborting tokenization at #{str.inspect} @#{@sc.pos}" }
    throw :_abort_
  end

  def tokenize(str, verbose: false)
    @verbose = verbose
    @sc = StringScanner.new(str.force_encoding(Encoding::BINARY))
    @token_stream = []
    catch :_abort_ do
      walk_scanner(_stop_at_pattern = nil)
    end
    @token_stream
  end

  def debug
    warn(yield) if @verbose
  end
end
