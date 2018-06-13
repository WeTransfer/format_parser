require 'spec_helper'

class NuObjectParser
  Malformed = Class.new(RuntimeError)
  RE = ->(str) { /#{Regexp.escape(str)}/ }
  STRATEGIES = {
    RE["/"]  => :parse_pdf_name,
    RE["<<"] => :parse_dictionary,
    RE["["]  => :parse_array,
    RE["("]  => :parse_string,
    RE["<"]  => :parse_hex_string,
    /\d+ \d+ R/ => :parse_ref,

    RE["true"]  => :wrap,
    RE["false"] => :wrap,
    RE["null"]  => :wrap,

    /\-?(\d+)\.(\d+)/ => :wrap_real,
    /\-?(\d+)/ => :wrap_int,

    RE["obj"]       => :wrap,
    RE["endobj"]    => :wrap,
    RE["stream"]    => :wrap,
    RE["endstream"] => :wrap,
#    RE[">>"]        => :wrap,
#    RE["]"]         => :wrap,
#    RE[">"]         => :wrap,
#    RE[")"]         => :wrap,

    /\s+/           => :wrap_whitespace,
  }

  STRING_ESCAPES = {
    "\r"   => "\n",
    "\n\r" => "\n",
    "\r\n" => "\n",
    "\\n"  => "\n",
    "\\r"  => "\r",
    "\\t"  => "\t",
    "\\b"  => "\b",
    "\\f"  => "\f",
    "\\("  => "(",
    "\\)"  => ")",
    "\\\\" => "\\",
    "\\\n" => "",
  }
  0.upto(9)   { |n| STRING_ESCAPES["\\00" + n.to_s] = ("00"+n.to_s).oct.chr }
  0.upto(99)  { |n| STRING_ESCAPES["\\0" + n.to_s]  = ("0"+n.to_s).oct.chr }
  0.upto(377) { |n| STRING_ESCAPES["\\" + n.to_s]   = n.to_s.oct.chr }

  def wrap_true(sc, pattern)
    @sc.scan(pattern)
    true
  end

  def wrap_false(pattern)
    @sc.scan(pattern)
    false
  end
  
  def wrap_nil(pattern)
    @sc.scan(pattern)
    nil
  end

  def wrap_real(pattern)
    @sc.scan(pattern).to_f
  end

  def wrap_int(pattern)
    @sc.scan(pattern).to_i
  end

  def wrap_whitespace(pattern)
    @sc.scan(pattern)
    :whitespace
  end

  def wrap(pattern)
    data = @sc.scan(pattern)
    data.to_sym
  end

  def consume!(pattern, method_name)
    return unless @sc.check(pattern)
    at = @sc.pos
    result = send(method_name, pattern)
    @token_stream << result unless result == :whitespace
    true
  end

  def parse_ref(start_pattern)
    [:ref, @sc.scan(start_pattern)]
  end

  def parse_array(start_pattern)
    @sc.scan(start_pattern) # consume [
    dict_open_at = @token_stream.length
    walk_scanner(RE["]"])
    raise Malformed, "Dictionary did not terminate" unless @token_stream.pop == :terminator
    array_items = @token_stream.pop(@token_stream.length - dict_open_at)
    [:array, array_items]
  end

  def parse_dictionary(start_pattern)
    @sc.scan(start_pattern) # consume <<
    dict_open_at = @token_stream.length
    walk_scanner(RE[">>"])
    raise Malformed, "Dictionary did not terminate" unless @token_stream.pop == :terminator
    dict_items = @token_stream.pop(@token_stream.length - dict_open_at)
    [:dict, dict_items]
  end

  def parse_string(start_pattern)
    rest_of_string = @sc.scan_until(/[^\\]\)/) # consume everything starting with ( and upto a non-escaped )
    raise Malformed, "String did not terminate (started at at #{@sc.pos})" unless rest_of_string
    rest_of_string[1..-2].gsub (/\\([nrtbf()\\\n]|\d{1,3})?|\r\n?|\n\r/m) do |match|
      STRING_ESCAPES[match] || ""
    end
  end

  def parse_pdf_name(start_pattern)
    letters = ('a'..'z').to_a.join + ('A'..'Z').to_a.join + "/"
    warn("Name parsing needs validation since start pattern is not the same as scan pattern")
    [:name, @sc.scan(/\/[#{letters}\d]+/)]
  end
  
  def walk_scanner(halt_at_pattern)
    until @sc.eos?
      # Terminate early
      if halt_at_pattern && halted = @sc.scan(halt_at_pattern)
        @token_stream << :terminator
        return
      end

      # Walk through STRATEGIES and stop iterating on first non-false call to consume!
      STRATEGIES.find do |pattern, method_name|
        consume!(pattern, method_name)
      end
    end
  end

  def parse(str)
    @sc = StringScanner.new(str)
    @token_stream = []
    walk_scanner(_stop_at_pattern = nil)
    @token_stream
  end
end

describe 'Object parser' do
  let(:fixture_paths) { Dir.glob(__dir__ + '/*.pdfobj').sort }

  xit 'scans the extracted object definitions from the corpus' do
    fixture_paths.each do |path|
      result = NuObjectParser.new.parse(File.read(path))
    end
  end

  it 'scans the example object from the PDF presentation' do
    obj = File.read(__dir__ + '/example_a.pdfobj')
    parser = NuObjectParser.new
    result = parser.parse(obj)
    expect(result).to eq(
      [
        [:array, [
          [:dict, [
            [:name, "/Name"], "Jim",
            [:name, "/Age"], 39,
            [:name, "/Children"], [:array, ["Heather", "Timothy", "Rebecca"]]]
          ],
          22,
          44.55]
        ]
      ]
    )
  end

  it 'scans a simple dictionary with strings and ints as values' do
    result = NuObjectParser.new.parse('<</Name (Jim) /Age 25>>')
    expect(result).to eq(
      [[:dict, [[:name, "/Name"], "Jim", [:name, "/Age"], 25]]]
    )
  end

  it 'scans a simple dictionary with arbitrary whitespace' do
    result = NuObjectParser.new.parse('<<
      /Name
        (Jim)
      /Age
        25>>')
    expect(result).to eq(
      [[:dict, [[:name, "/Name"], "Jim", [:name, "/Age"], 25]]]
    )
  end

  it 'parses an array of integers' do
    result = NuObjectParser.new.parse('[1 2 3 4]')
    expect(result).to eq(
      [[:array, [1, 2, 3, 4]]]
    )
  end

  it 'scans an array of integers with one object ref in the middle' do
    result = NuObjectParser.new.parse('[1 20 00 R 3]')
    expect(result).to eq(
      [[:array, [1, [:ref, "20 00 R"], 3]]]
    )
  end

  it 'scans an array of names' do
    result = NuObjectParser.new.parse('[ /Type /Color /Medium/Rare ]')
    expect(result).to eq(
      [[:array, [[:name, "/Type"], [:name, "/Color"], [:name, "/Medium/Rare"]]]]
    )
  end

  it 'handles string escapes' do
    result = NuObjectParser.new.parse("(Foo \\(with some bars\\))")
    expect(result).to eq(
      ["Foo (with some bars)"]
    )
  end

  it 'detects an unterminated string' do
    expect {
      NuObjectParser.new.parse("(Hello there")
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated array' do
    expect {
      NuObjectParser.new.parse("[")
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated dictionary' do
    expect {
      NuObjectParser.new.parse("<< /Ohai")
    }.to raise_error(/did not terminate/)
  end

  it 'detects a truncated dictionary opener' do
    expect {
      NuObjectParser.new.parse('<</')
    }.to raise_error(/did not terminate/)
  end
end
