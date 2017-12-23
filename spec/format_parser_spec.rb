require 'spec_helper'

describe FormatParser do
  it 'returns nil when trying to parse an empty IO' do
    d = StringIO.new('')
    expect(FormatParser.parse(d)).to be_nil
  end

  it 'returns nil when parsing an IO no parser can make sense of' do
    d = StringIO.new(Random.new.bytes(1))
    expect(FormatParser.parse(d)).to be_nil
  end

  describe 'with fuzzing' do
    it 'returns nil for all fuzzed results' do
      1024.times do
        random_blob = StringIO.new(Random.new.bytes(512 * 1024))
        expect(FormatParser.parse(random_blob)).to be_nil
      end
    end
  end
end
