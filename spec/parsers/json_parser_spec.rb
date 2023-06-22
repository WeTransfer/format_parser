require 'spec_helper'

describe FormatParser::JSONParser do
  MAX_READS = 100

  def parse(file_name)
    io = File.open(Pathname.new(fixtures_dir).join('JSON').join(file_name), 'rb')
    limited_io = FormatParser::ReadLimiter.new(io, max_reads: MAX_READS)
    subject.call(limited_io)
  end

  describe 'Valid JSON files' do
    it "is able to identify JSON files with objects as root nodes" do
      parsed = parse 'object.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is able to identify JSON files carrying arrays as root nodes" do
      parsed = parse 'array.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is able to parse formatted JSON files" do
      parsed = parse 'formatted_object_utf8.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is able to parse files wrapped in whitespace characters" do
      parsed = parse 'whitespaces.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is able to parse files with nested objects and arrays" do
      parsed = parse 'nested_objects.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is able to parse files with escaped chars in strings" do
      parsed = parse 'escaped_strings.json'

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end
  end

  describe 'Invalid JSON files' do
    it "rejects files not starting '{' or '[' without extra reads" do
      parsed = parse 'lorem_ipsum.json'

      expect(parsed).to be_nil
    end

    it "rejects files with corrupted JSON data" do
      parsed = parse 'malformed.json'

      expect(parsed).to be_nil
    end
  end

  describe 'IO limits JSON files' do
    it "rejects files not starting '{' or '[' without extra reads" do
      parsed = parse 'lorem_ipsum.json'

      expect(parsed).to be_nil
    end

    it "rejects files with corrupted JSON data" do
      parsed = parse 'malformed.json'

      expect(parsed).to be_nil
    end
  end
end
