require 'spec_helper'

describe FormatParser::JSONParser do
  MAX_READS = 100

  def load_file(file_name)
    io = File.open(Pathname.new(fixtures_dir).join('JSON').join(file_name), 'rb')
    FormatParser::ReadLimiter.new(io, max_reads: MAX_READS)
  end

  def file_size(file_name)
    File.size(Pathname.new(fixtures_dir).join('JSON').join(file_name))
  end

  describe 'When reading objects valid JSON files' do
    it "identifies JSON files with objects as root nodes" do
      io = load_file 'object.json'

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "identifies JSON files carrying arrays as root nodes" do
      io = load_file 'array.json'

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "identifies formatted JSON files" do
      io = load_file 'formatted_object_utf8.json'

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "identifies files wrapped in whitespace characters" do
      io = load_file 'whitespaces.json'

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "identifies files with nested objects and arrays" do
      io = load_file 'nested_objects.json'

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
    end

    it "is reads the whole content of small files before accepting them" do
      file_name = 'nested_objects.json'
      io = load_file file_name
      file_size = file_size file_name

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
      expect(io.bytes).to be >= file_size
    end

    it "is accepts long files before reading the whole content" do
      file_name = 'long_array_numbers.json'
      io = load_file file_name
      file_size = file_size file_name

      parsed = subject.call(io)

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:text)
      expect(parsed.format).to eq(:json)
      expect(parsed.content_type).to eq('application/json')
      expect(io.bytes).to be < file_size
    end

  end

  describe 'When reading objects invalid JSON files' do
    it "rejects files with corrupted JSON data" do
      io = load_file 'malformed.json'

      parsed = subject.call(io)

      expect(parsed).to be_nil
    end

    it "rejects invalid files early without reading the whole content" do
      io = load_file 'lorem_ipsum.json'

      parsed = subject.call(io)

      expect(parsed).to be_nil
      expect(io.reads).to eq(1)
    end
  end

end
