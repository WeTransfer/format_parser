require 'spec_helper'

describe FormatParser do
  it 'exposes VERSION' do
    expect(FormatParser::VERSION).to be_kind_of(String)
  end

  describe '.parse' do
    it 'returns nil when trying to parse an empty IO' do
      d = StringIO.new('')
      expect(FormatParser.parse(d)).to be_nil
    end

    it 'returns nil when parsing an IO no parser can make sense of' do
      d = StringIO.new(Random.new.bytes(1))
      expect(FormatParser.parse(d)).to be_nil
    end

    it 'uses the passed ReadLimitsConfig and applies limits in it' do
      conf = FormatParser::ReadLimitsConfig.new(16)
      d = StringIO.new(Random.new.bytes(64 * 1024))
      expect(FormatParser.parse(d, limits_config: conf)).to be_nil
    end

    it 'parses our fixtures without raising any errors' do
      Dir.glob(fixtures_dir + '/**/*.*').sort.each do |fixture_path|
        File.open(fixture_path, 'rb') do |file|
          FormatParser.parse(file)
        end
      end
    end

    it "returns either a valid result or a nil for all fuzzed inputs at seed #{RSpec.configuration.seed}" do
      r = Random.new(RSpec.configuration.seed)
      1024.times do
        random_blob = StringIO.new(r.bytes(512 * 1024))
        FormatParser.parse(random_blob) # If there is an error in one of the parsers the example will raise too
      end
    end

    it 'fails gracefully when a parser module reads more and more causing page faults and prevents too many reads on the source' do
      exploit = ->(io) {
        loop {
          skip = 16 * 1024
          io.read(1)
          io.seek(io.pos + skip)
        }
      }
      FormatParser.register_parser exploit, natures: :document, formats: :exploit

      sample_io = StringIO.new(Random.new.bytes(1024 * 1024 * 8))
      allow(sample_io).to receive(:read).and_call_original

      result = FormatParser.parse(sample_io, formats: [:exploit])

      expect(sample_io).to have_received(:read).at_most(16).times
      expect(result).to be_nil

      FormatParser.deregister_parser(exploit)
    end

    describe 'when multiple results are requested' do
      let(:blob) { StringIO.new(Random.new.bytes(512 * 1024)) }
      let(:audio) { FormatParser::Audio.new(format: :aiff, num_audio_channels: 1) }
      let(:image) { FormatParser::Image.new(format: :dpx, width_px: 1, height_px: 1) }

      context 'with :result=> :all (multiple results)' do
        before do
          expect_any_instance_of(FormatParser::AIFFParser).to receive(:call).and_return(audio)
          expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
        end

        subject { FormatParser.parse(blob, results: :all) }

        it { is_expected.to include(image) }
        it { is_expected.to include(audio) }
      end

      context 'without :result=> :all (first result)' do
        before do
          expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
        end

        subject { FormatParser.parse(blob) }

        it { is_expected.to eq(image) }
      end
    end
  end

  describe '.parse_file_at' do
    it 'parses a fixture when given a path to it' do
      path = fixtures_dir + '/WAV/c_M1F1-Alaw-AFsp.wav'
      result = FormatParser.parse_file_at(path)
      expect(result.nature).to eq(:audio)
    end

    it 'passes keyword arguments to parse()' do
      path = fixtures_dir + '/WAV/c_M1F1-Alaw-AFsp.wav'
      expect(FormatParser).to receive(:parse).with(an_instance_of(File), foo: :bar)
      FormatParser.parse_file_at(path, foo: :bar)
    end
  end

  describe '.parsers_for' do
    it 'raises on an invalid request' do
      expect {
        FormatParser.parsers_for([:image], [:fdx])
      }.to raise_error(/No parsers provide/)
    end

    it 'returns an intersection of all parsers supplying natures and formats requested' do
      image_parsers = FormatParser.parsers_for([:image], [:tif, :jpg])
      expect(image_parsers.length).to eq(2)
    end

    it 'omits parsers not matching formats' do
      image_parsers = FormatParser.parsers_for([:image, :audio], [:tif, :jpg])
      expect(image_parsers.length).to eq(2)
    end

    it 'omits parsers not matching nature' do
      image_parsers = FormatParser.parsers_for([:image], [:tif, :jpg, :aiff, :mp3])
      expect(image_parsers.length).to eq(2)
    end
  end

  describe '.register_parser and .deregister_parser' do
    it 'registers a parser for a certain nature and format' do
      some_parser = ->(_io) { 'I parse EXRs! Whee!' }

      expect {
        FormatParser.parsers_for([:image], [:exr])
      }.to raise_error(/No parsers provide/)

      FormatParser.register_parser some_parser, natures: :image, formats: :exr

      image_parsers = FormatParser.parsers_for([:image], [:exr])
      expect(image_parsers).not_to be_empty

      FormatParser.deregister_parser some_parser
      expect {
        FormatParser.parsers_for([:image], [:exr])
      }.to raise_error(/No parsers provide/)
    end
  end

  describe '.default_limits_config' do
    it 'returns a ReadLimitsConfig object' do
      expect(FormatParser.default_limits_config).to be_kind_of(FormatParser::ReadLimitsConfig)
    end
  end
end
