require 'spec_helper'
require_relative 'nu_object_parser'

describe 'Object parser' do
  describe 'with extracted objects from corpus' do
    fixture_paths = Dir.glob(__dir__ + '/*.pdfobj').sort
    fixture_paths.each do |path|
      it "scans #{File.basename(path)}" do
        result = NuObjectParser.new.parse(File.read(path))
        require 'pp'
        pp result
      end
    end
  end

  it 'scans the example object from the PDF presentation' do
    obj = File.read(__dir__ + '/example_a.pdfobj')
    parser = NuObjectParser.new
    result = parser.parse(obj)
    expect(result).to eq(
      [
        [
          :array, [
            [
              :dict, [
                [:name, '/Name'], 'Jim',
                [:name, '/Age'], [:int, 39],
                [:name, '/Children'], [:array, ['Heather', 'Timothy', 'Rebecca']]
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
    result = NuObjectParser.new.parse('<</Name (Jim) /Age 25>>')
    expect(result).to eq(
      [[:dict, [[:name, '/Name'], 'Jim', [:name, '/Age'], [:int, 25]]]]
    )
  end

  it 'scans a simple dictionary with arbitrary whitespace' do
    result = NuObjectParser.new.parse('<<
      /Name
        (Jim)
      /Age
        25>>')
    expect(result).to eq(
      [[:dict, [[:name, '/Name'], 'Jim', [:name, '/Age'], [:int, 25]]]]
    )
  end

  it 'parses all kinds of reals' do
    result = NuObjectParser.new.parse('34.5 -3.62 +123.6 4. -.002 0.0')
    expect(result).to eq(
      [[:real, 34.5], [:real, -3.62], [:real, 123.6], [:real, 4.0], [:real, -0.002], [:real, 0.0]]
    )
  end

  it 'parses an array of integers' do
    result = NuObjectParser.new.parse('[1 2 3 4]')
    expect(result).to eq(
      [[:array, [[:int, 1], [:int, 2], [:int, 3], [:int, 4]]]]
    )
  end

  it 'scans an array of integers with one object ref in the middle' do
    result = NuObjectParser.new.parse('[1 20 00 R 3]')
    expect(result).to eq(
      [[:array, [[:int, 1], [:ref, '20 00 R'], [:int, 3]]]]
    )
  end

  it 'scans an array of names' do
    result = NuObjectParser.new.parse('[ /Type /Color /Medium/Rare ]')
    expect(result).to eq(
      [[:array, [[:name, '/Type'], [:name, '/Color'], [:name, '/Medium'], [:name, '/Rare']]]]
    )

    result = NuObjectParser.new.parse('[/Type/Color/Medium/Rare]')
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
    result = NuObjectParser.new.parse(names_str)
    expect(result).to eq([
      [:name, '/Name1'],
      [:name, '/ASomewhatLongerName'],
      [:name, '/A;Name_With-Various***Characters?'],
      [:name, '/1.2'],
      [:name, '/$$'],
      [:name, '/@pattern'],
      [:name, '/.notdef'],
      [:name, '/Adobe Green'],
      [:name, '/PANTONE 5757 CV'],
      [:name, '/paired()parentheses'],
      [:name, '/The_Key_of_F#_Minor'],
      [:name, '/AB'],
      [:name, '/']
    ])
  end

  it 'handles string escapes' do
    result = NuObjectParser.new.parse('(Foo \\(with some bars\\))')
    expect(result).to eq(
      ['Foo (with some bars)']
    )
  end

  it 'handles paired braces in strings escapes' do
    result = NuObjectParser.new.parse('(Foo () bar and (baz))')
    expect(result).to eq(
      ['Foo (with some bars)']
    )
  end

  it 'detects an unterminated string' do
    expect {
      NuObjectParser.new.parse('(Hello there')
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated array' do
    expect {
      NuObjectParser.new.parse('[')
    }.to raise_error(/did not terminate/)
  end

  it 'detects an unterminated dictionary' do
    expect {
      NuObjectParser.new.parse('<< /Ohai')
    }.to raise_error(/did not terminate/)
  end

  it 'detects a truncated dictionary opener' do
    expect {
      NuObjectParser.new.parse('<</')
    }.to raise_error(/PDF name at 2/)
  end

  it 'responds well to fuzzed input' do
    random = Random.new(12345)
    1024.times do
      begin
        result = NuObjectParser.new.parse(random.bytes(128))
        expect(result).to be_kind_of(Array)
      rescue NuObjectParser::Malformed
        # Everything good, we failed as we should
      end
    end
  end
end
