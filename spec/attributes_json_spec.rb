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
end
