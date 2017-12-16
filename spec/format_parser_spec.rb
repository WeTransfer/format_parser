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
end
