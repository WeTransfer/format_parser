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

  context 'when two natures are returned' do
    # TODO: Add FactoryGurl to the specs.
    let(:gif) { FormatParser::Image.new(format: :gif) }
    let(:audio) { FormatParser::Audio.new(format: :aiff) }
    before do
      expect_any_instance_of(FormatParser::Parsers::Image::GIFParser).to receive(:call).and_return(gif)
      expect_any_instance_of(FormatParser::Parsers::Audio::AIFFParser).to receive(:call).and_return(audio)
    end
    subject { FormatParser.parse(StringIO.new('')) }

    it { expect(subject.natures).to include(:audio) }
    it { expect(subject.natures).to include(:image) }
    it { expect(subject.audio).to eq(audio) }
    it { expect(subject.image).to eq(gif) }
    it { expect(subject.document).to be_nil }
    it { expect(subject.video).to be_nil }
  end

  describe 'with fuzzing' do
    it "returns either a valid result or a nil for all fuzzed inputs at seed #{RSpec.configuration.seed}" do
      r = Random.new(RSpec.configuration.seed)
      1024.times do
        random_blob = StringIO.new(r.bytes(512 * 1024))
        FormatParser.parse(random_blob) # If there is an error in one of the parsers the example will raise too
      end
    end
  end
end
