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
    it "returns either a valid result or a nil for all fuzzed inputs at seed #{RSpec.configuration.seed}" do
      r = Random.new(RSpec.configuration.seed)
      1024.times do
        random_blob = StringIO.new(r.bytes(512 * 1024))
        FormatParser.parse(random_blob) # If there is an error in one of the parsers the example will raise too
      end
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

  describe 'multiple values return' do
    let(:blob) { StringIO.new(Random.new.bytes(512 * 1024)) }
    let(:audio) { FormatParser::Audio.new(format: :aiff, num_audio_channels: 1) }
    let(:image) { FormatParser::Image.new(format: :dpx, width_px: 1, height_px: 1) }

    context '.parse called with options' do
      before do
        expect_any_instance_of(FormatParser::AIFFParser).to receive(:call).and_return(audio)
        expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
      end

      subject { FormatParser.parse(blob, results: :all) }

      it { is_expected.to include(image) }
      it { is_expected.to include(audio) }
    end

    context '.parse called without hash options' do
      before do
        expect_any_instance_of(FormatParser::DPXParser).to receive(:call).and_return(image)
      end

      subject { FormatParser.parse(blob) }

      it { is_expected.to eq(image) }
    end
  end

  describe '.parse_file_at' do
    it 'parses a fixture when given a path to it' do
      path = fixtures_dir + '/WAV/c_M1F1-Alaw-AFsp.wav'
      result = FormatParser.parse_file_at(path)
      expect(result.nature).to eq(:audio)
    end
  end

  describe 'when parsing fixtures' do
    Dir.glob(fixtures_dir + '/**/*.*').sort.each do |fixture_path|
      it "parses #{fixture_path} without raising any errors" do
        File.open(fixture_path, 'rb') do |file|
          FormatParser.parse(file)
        end
      end
    end
  end

  describe 'parsers_for' do
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

  describe 'parser registration and deregistration with the module' do
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
end
