require 'spec_helper'

describe FormatParser::JSONParser::Validator do
  def load_file(file_name)
    io = File.open(Pathname.new(fixtures_dir).join('JSON').join(file_name), 'rb')
    FormatParser::JSONParser::Validator.new(io)
  end

  def load_string(content)
    io = StringIO.new(content.encode(Encoding::UTF_8))
    FormatParser::JSONParser::Validator.new(io)
  end

  describe 'When reading root nodes' do
    it "identifies objects as root nodes" do
      v = load_string '{"key": "value"}'

      completed = v.validate

      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 2
    end

    it "identifies arrays as root nodes" do
      v = load_string '["e1", "e2"]'

      completed = v.validate

      expect(completed).to be true
      expect(v.stats(:array)).to be 1
      expect(v.stats(:string)).to be 2
    end

    it "rejects strings as root nodes" do
      expect do
        v = load_string '"this is a string"'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end

    it "rejects literals as root nodes" do
      expect do
        v = load_string 'true'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end
  end

  describe 'When reading objects' do
    it "recognizes empty objects" do
      v = load_string '{}'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 0
    end

    it "recognizes objects with a single attribute" do
      v = load_string '{"key": "value"}'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 2
    end

    it "recognizes objects with attributes of different types" do
      v = load_string '{"k1": "value", "k2": -123.456, "k3": null}'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 4
      expect(v.stats(:literal)).to be 2
    end

    it "recognizes condensed objects (no whitespaces)" do
      v = load_string '{"a":"b","c":"d"}'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 4
    end

    it "recognizes formatted objects" do
      v = load_string '{
        "a":"b",
        "c":"d"
      }'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 4
    end

    it "recognizes objects with nested objects and arrays" do
      v = load_string '{
        "a": {
          "a1": "-",
          "a2": "-",
          "a3": {
            "a3.1": "-"
          },
        },
        "c": [1, null]
      }'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:object)).to be 3
      expect(v.stats(:array)).to be 1
      expect(v.stats(:string)).to be 9
      expect(v.stats(:literal)).to be 2
    end

    it "rejects objects without double-quoted attribute names" do
      expect do
        v = load_string '{a:"b",c:"d"}'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end

    it "rejects objects without comma separators" do
      expect do
        v = load_string '{
          "a":"b"
          "c":"d"
        }'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end
  end

  describe 'When reading arrays' do
    it "recognizes empty arrays" do
      v = load_string '[]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 1
      expect(v.stats(:string)).to be 0
    end

    it "recognizes arrays with a single element" do
      v = load_string '[{}]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 1
      expect(v.stats(:object)).to be 1
    end

    it "recognizes arrays with elements of different types" do
      v = load_string '[{"k1": "value"}, [], "a string", null, -123.456]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 2
      expect(v.stats(:object)).to be 1
      expect(v.stats(:string)).to be 3
      expect(v.stats(:literal)).to be 2
    end

    it "recognizes condensed arrays (no whitespaces)" do
      v = load_string '["a",2,null,false]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 1
      expect(v.stats(:string)).to be 1
      expect(v.stats(:literal)).to be 3
    end

    it "recognizes formatted arrays" do
      v = load_string '[
        {
          "a":"b"
        },
        {
          "c":"d"
        }
      ]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 1
      expect(v.stats(:object)).to be 2
      expect(v.stats(:string)).to be 4
    end

    it "recognizes arrays with nested objects and arrays" do
      v = load_string '[{
          "a": {
            "a1": "-",
            "a2": "-",
            "a3": {
              "a3.1": "-"
            },
          },
          "c": [1, null]
        },
        [{ "a": "b" }, { "c":"d" }]
      ]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:array)).to be 3
      expect(v.stats(:object)).to be 5
      expect(v.stats(:string)).to be 13
      expect(v.stats(:literal)).to be 2
    end

    it "rejects arrays without comma separators" do
      expect do
        v = load_string '[
          "abc"
          "def"
        ]'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end
  end

  describe 'When reading strings' do
    it "recognizes regular strings" do
      v = load_string '["abc", "def", "ghi"]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:string)).to be 3
    end

    it "recognizes strings containing excaped characters" do
      v = load_string '["ab\"c", "6\\2=3"]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:string)).to be 2
    end

    it "recognizes strings containing UTF8 characters" do
      v = load_string '["abc😃🐶👀", "😃2🐶3👀"]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:string)).to be 2
    end

    it "recognizes long strings containing UTF8 characters" do
      v = load_string '["aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀aØڃಚ😁🐶👀"]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:string)).to be 1
    end
  end

  describe 'When reading literals' do
    it "recognizes numbers" do
      v = load_string '[1, -2.4, 1.0E+2]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:literal)).to be 3
    end

    it "recognizes boolean values" do
      v = load_string '[true, false]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:literal)).to be 2
    end

    it "recognizes 'true', 'false' and 'null'" do
      v = load_string '[true, false, null]'

      completed = v.validate
      expect(completed).to be true
      expect(v.stats(:literal)).to be 3
    end
  end

  describe 'When reading invalid JSON content' do
    it "rejects truncated JSON content" do
      expect do
        v = load_string '[{
          "a": ["abc","def"],
          "b": 4'
        v.validate
        end.to raise_error(FormatParser::JSONParser::Validator::JSONParserError)
    end
  end

  describe 'When reading large JSON files' do
    it "Returns 'false' without throwing errors when the initial chunk of a file is a valid JSON" do
        v = load_file 'long_file_valid.json'

        completed = v.validate
        expect(completed).to be false
    end

    it "Returns 'false' without throwing errors when for long non-formatted JSON files" do
      v = load_file 'long_file_valid_non_formatted.json'

      completed = v.validate
      expect(completed).to be false
    end

    it "Returns 'false' without throwing errors when the initial chunk of a file is a valid JSON even if there's an issue later" do
      v = load_file 'long_file_malformed.json'

      completed = v.validate
      expect(completed).to be false
    end
  end
end
