require 'spec_helper'

describe FormatParser::AttributesJSON do
  it 'returns a hash of all the accessorized properties' do
    anon_class = Class.new do
      include FormatParser::AttributesJSON
      attr_accessor :foo, :bar, :baz
      def nature
        'good'
      end
    end
    instance = anon_class.new
    instance.foo = 42
    instance.bar = 'abcdef'
    expect(instance.as_json).to eq('nature' => 'good', 'foo' => 42, 'bar' => 'abcdef', 'baz' => nil)
    expect(instance.as_json(root: true)).to eq('format_parser_file_info' => {'nature' => 'good', 'foo' => 42, 'bar' => 'abcdef', 'baz' => nil})
  end

  it 'is included into file information types' do
    [
      FormatParser::Image,
      FormatParser::Video,
      FormatParser::Audio,
      FormatParser::Document
    ].each do |file_related_class|
      expect(file_related_class.ancestors).to include(FormatParser::AttributesJSON)
    end
  end

  it 'converts Float::INFINITY to nil' do
    anon_class = Class.new do
      include FormatParser::AttributesJSON
      attr_accessor :some_infinity
      def some_infinity
        Float::INFINITY
      end
    end
    instance = anon_class.new
    output = JSON.dump(instance)
    readback = JSON.parse(output, symbolize_names: true)
    expect(readback).to have_key(:some_infinity)
    expect(readback[:some_infinity]).to be_nil
  end

  it 'converts NaN to nil' do
    anon_class = Class.new do
      include FormatParser::AttributesJSON
      attr_accessor :some_nan
      def some_nan
        (1.0 / 0.0).to_f
      end
    end
    instance = anon_class.new
    output = JSON.dump(instance)
    readback = JSON.parse(output, symbolize_names: true)
    expect(readback).to have_key(:some_nan)
    expect(readback[:some_nan]).to be_nil
  end

  it 'provides a default implementation of to_json as well' do
    anon_class = Class.new do
      include FormatParser::AttributesJSON
      attr_accessor :foo, :bar, :baz
      def nature
        'good'
      end
    end
    instance = anon_class.new
    instance.foo = 42
    instance.bar = 'abcdef'

    output = JSON.dump(instance)
    readback = JSON.parse(output, symbolize_names: true)

    expect(readback).to have_key(:nature)

    # Make sure we support pretty_generate correctly
    pretty_output = JSON.pretty_generate(instance)
    standard_output = JSON.dump(instance)
    expect(pretty_output).not_to eq(standard_output)
  end

  it 'provides to_json without arguments' do
    anon_class = Class.new do
      include FormatParser::AttributesJSON
      attr_accessor :foo, :bar, :baz
      def nature
        'good'
      end
    end
    instance = anon_class.new
    instance.foo = 42
    instance.bar = 'abcdef'

    output = instance.to_json
    readback = JSON.parse(output, symbolize_names: true)

    expect(readback).to have_key(:nature)
  end

  it 'converts purely-binary String objects deeply nested in the struct to escapes and question marks' do
    nasty_hash = {
      id: 'TIT2',
      size: 37,
      flags: "\x00\x00",
      struct: Struct.new(:key).new("Value"),
      content: "\x01\xFF\xFEb\x00i\x00r\x00d\x00s\x00 \x005\x00 \x00m\x00o\x00r\x00e\x00 \x00c\x00o\x00m\x00p\x00".b
    }
    expect {
      JSON.pretty_generate(nasty_hash) # Should not raise an error
    }.to raise_error(Encoding::UndefinedConversionError)

    anon_class = Struct.new(:evil)
    anon_class.include FormatParser::AttributesJSON

    object_with_attributes_module = anon_class.new(nasty_hash)
    output = JSON.pretty_generate(object_with_attributes_module)

    parsed_output = JSON.parse(output, symbolize_names: true)

    expect(parsed_output[:evil][:struct]).to eq({:key=>"Value"})
    expect(parsed_output[:evil][:id]).to eq('TIT2')
    expect(parsed_output[:evil][:flags]).to be_kind_of(String)
  end
end
