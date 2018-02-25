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
    expect(instance.as_json(root: true)).to eq('nature' => 'good', 'foo' => 42, 'bar' => 'abcdef', 'baz' => nil)
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
end
