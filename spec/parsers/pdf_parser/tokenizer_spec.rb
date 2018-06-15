require 'spec_helper'

describe FormatParser::PDFParser::Tokenizer do
  def tokenize(str)
    FormatParser::PDFParser::Tokenizer.new.tokenize(str)
  end

  def tokenize_file_at(at_path)
    FormatParser::PDFParser::Tokenizer.new.tokenize(File.read(at_path))
  end

  describe 'with extracted objects from corpus' do
    fixture_paths = Dir.glob(__dir__ + '/*.pdfobj').sort
    fixture_paths.each do |path|
      it "scans #{File.basename(path)}" do
        result = tokenize_file_at(path)
        require 'pp'
        pp result
      end
    end
  end

  it 'scans the example object from the PDF presentation' do
    result = tokenize_file_at(__dir__ + '/example_a.pdfobj')
    expect(result).to eq(
      [
        [
          :array, [
            [
              :dict, [
                [:name, '/Name'], 'Jim',
                [:name, '/Age'], [:int, 39],
                [:name, '/Children'],
                [:array, [
                    [:str, 'Heather'],
                    [:str, 'Timothy'],
                    [:str, 'Rebecca']
                ]]
              ]
            ],
            [:int, 22],
            [:real, 44.55]
          ]
        ]
      ]
    )
  end

  it 'scans a simple dictionary with strings and ints as values' do
    result = tokenize('<</Name (Jim) /Age 25>>')
    expect(result).to eq(
      [[:dict, [[:name, "/Name"], [:str, "Jim"], [:name, "/Age"], [:int, "25"]]]]
    )
  end

  it 'scans a simple dictionary with arbitrary whitespace' do
    result = tokenize('<<
      /Name
        (Jim)
      /Age
        25>>')
    expect(result).to eq(
      [[:dict, [[:name, "/Name"], [:str, "Jim"], [:name, "/Age"], [:int, "25"]]]]
    )
  end

  it 'parses all kinds of reals' do
    result = tokenize('34.5 -3.62 +123.6 4. -.002 0.0')
    expect(result).to eq(
      [[:real, "34.5"], [:real, "-3.62"], [:real, "+123.6"], [:real, "4."], [:real, "-.002"], [:real, "0.0"]]
    )
  end

  it 'parses an array of integers' do
    result = tokenize('[1 2 3 4]')
    expect(result).to eq(
      [[:array, [[:int, "1"], [:int, "2"], [:int, "3"], [:int, "4"]]]]
    )
  end

  it 'scans an array of integers with one object ref in the middle' do
    result = tokenize('[1 20 00 R 3]')
    expect(result).to eq(
      [[:array, [[:int, "1"], [:ref, "20 00 R"], [:int, "3"]]]]
    )
  end

  it 'scans an array of names' do
    result = tokenize('[ /Type /Color /Medium/Rare ]')
    expect(result).to eq(
      [[:array, [[:name, '/Type'], [:name, '/Color'], [:name, '/Medium'], [:name, '/Rare']]]]
    )

    result = tokenize('[/Type/Color/Medium/Rare]')
    expect(result).to eq(
      [[:array, [[:name, '/Type'], [:name, '/Color'], [:name, '/Medium'], [:name, '/Rare']]]]
    )
  end

  it 'handles names' do
    names_str = %(
      /Name1
      /ASomewhatLongerName /A;Name_With-Various***Characters? /1.2
      /$$
      /@pattern
      /.notdef
      /Adobe#20Green
      /PANTONE#205757#20CV
      /paired#28#29parentheses
      /The_Key_of_F#23_Minor
      /A#42
      /
    )
    result = tokenize(names_str)
    expect(result).to eq([
      [:name, "/Name1"],
      [:name, "/ASomewhatLongerName"],
      [:name, "/A;Name_With-Various***Characters?"],
      [:name, "/1.2"],
      [:name, "/$$"],
      [:name, "/@pattern"],
      [:name, "/.notdef"],
      [:name, "/Adobe#20Green"],
      [:name, "/PANTONE#205757#20CV"],
      [:name, "/paired#28#29parentheses"],
      [:name, "/The_Key_of_F#23_Minor"],
      [:name, "/A#42"],
      [:name, "/"]
    ])
  end

  it 'handles paired braces and strings escapes' do
    result = tokenize('
      (Foo \\(with some bars\\))
      (Foo () bar and (baz))
      (Foo (with some bars))
      (((())))
    ')
    expect(result).to eq(
      [[:str, "Foo \\(with some bars\\)"], [:str, "Foo () bar and (baz)"], [:str, "Foo (with some bars)"], [:str, "((()))"]]
    )
  end

  it 'detects an unterminated string' do
    expect {
      tokenize('(Hello there')
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated array' do
    expect {
      tokenize('[')
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated dictionary' do
    expect {
      tokenize('<< /Ohai')
    }.to raise_error(/did not terminate/)
  end

  it 'detects a truncated dictionary opener' do
    expect {
      tokenize('<</')
    }.to raise_error(/Dictionary did not terminate/)
  end

  it 'responds well to fuzzed input' do
    random = Random.new(12345)
    1024.times do
      begin
        result = tokenize(random.bytes(128))
        expect(result).to be_kind_of(Array)
      rescue FormatParser::PDFParser::Tokenizer::Malformed
        # Everything good, we failed as we should
      end
    end
  end
end
