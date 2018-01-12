require 'spec_helper'

describe FormatParser do
  it 'returns nil when trying to parse an empty IO' do
    d = StringIO.new('')
    expect(FormatParser.parse(d)).to be_empty
  end

  it 'returns nil when parsing an IO no parser can make sense of' do
    d = StringIO.new(Random.new.bytes(1))
    expect(FormatParser.parse(d)).to be_empty
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

  describe 'multiple values return' do
    let(:blob) { StringIO.new(Random.new.bytes(512 * 1024)) }
    let(:audio) { FormatParser::Audio.new(format: :aiff, num_audio_channels: 1) }
    let(:image) { FormatParser::Image.new(format: :dpx, width_px: 1, height_px: 1) }

    context '#parse called without any option' do
      before do
        expect_any_instance_of(FormatParser::AIFFParser).to receive(:call).and_return(audio)
        expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
      end

      subject { FormatParser.parse(blob) }

      it { is_expected.to include(image) }
      it { is_expected.to include(audio) }
    end

    context '#parse called with hash options' do
      before do
        expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
      end

      subject { FormatParser.parse(blob, formats: [:dpx], limit: 1) }

      it { is_expected.to include(image) }
    end
  end
end
