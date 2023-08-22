require 'spec_helper'

describe FormatParser do
  it 'exposes VERSION' do
    expect(FormatParser::VERSION).to be_kind_of(String)
  end

  it 'exposes the Measurometer constant' do
    expect(FormatParser::Measurometer).to be_kind_of(Module)
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

    it 'triggers parsers in a certain order that corresponds to the parser priorities' do
      file_contents = StringIO.new('a' * 4096)

      parsers_called_order = []
      expect_any_instance_of(FormatParser::PNGParser).to receive(:call) { |instance|
        parsers_called_order << instance.class
        nil
      }
      expect_any_instance_of(FormatParser::MP3Parser).to receive(:call) { |instance|
        parsers_called_order << instance.class
        nil
      }
      expect_any_instance_of(FormatParser::ZIPParser).to receive(:call) { |instance|
        parsers_called_order << instance.class
        nil
      }

      FormatParser.parse(file_contents)

      png_parser_idx = parsers_called_order.index(FormatParser::PNGParser)
      mp3_parser_idx = parsers_called_order.index(FormatParser::MP3Parser)
      zip_parser_idx = parsers_called_order.index(FormatParser::ZIPParser)

      # The PNG parser should have been applied first
      expect(png_parser_idx).to be < zip_parser_idx
      # ...and the ZIP parser second (MP3 is the most omnivorous since there
      # is no clear header or footer in the file
      expect(mp3_parser_idx).to be > zip_parser_idx
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

    it 'correctly detects a PNG as a PNG without falling back to another filetype' do
      File.open(fixtures_dir + '/PNG/simulator_screenie.png', 'rb') do |file|
        file_information = FormatParser.parse(file)
        expect(file_information).not_to be_nil
        expect(file_information.format).to eq(:png)
      end
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
      expect(FormatParser).to receive(:parse).with(an_instance_of(File), filename_hint: 'c_M1F1-Alaw-AFsp.wav', foo: :bar)
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

    it 'returns an array with the ZIPParser first if the filename_hint is for a ZIP file' do
      prioritized_parsers = FormatParser.parsers_for([:archive, :document, :image, :audio], [:tif, :jpg, :zip, :docx, :mp3, :aiff], nil)
      expect(prioritized_parsers.first).not_to be_kind_of(FormatParser::ZIPParser)

      prioritized_parsers = FormatParser.parsers_for([:archive, :document, :image, :audio], [:tif, :jpg, :zip, :docx, :mp3, :aiff], 'a-file.zip')
      expect(prioritized_parsers.first).to be_kind_of(FormatParser::ZIPParser)
    end

    it 'sorts the parsers by priority and name' do
      parsers = FormatParser.parsers_for(
        [:audio, :image],
        [:cr2, :cr3, :dpx, :fdx, :flac, :gif, :jpg, :mov, :mp4, :m4a, :mp3, :mpg, :mpeg, :ogg, :png, :tif, :wav]
      )

      expect(parsers.map { |parser| parser.class.name }).to eq([
        'FormatParser::GIFParser',
        'Class',
        'FormatParser::PNGParser',
        'FormatParser::MP4Parser',
        'FormatParser::CR2Parser',
        'FormatParser::CR3Parser',
        'FormatParser::DPXParser',
        'FormatParser::FLACParser',
        'FormatParser::OggParser',
        'FormatParser::TIFFParser',
        'FormatParser::WAVParser',
        'FormatParser::MP3Parser'
      ])
    end

    it 'ensures that MP3 parser is the last one among all' do
      parsers = FormatParser.parsers_for(
        [:audio, :image, :document, :text, :video, :archive],
        [:aac, :aiff, :arw, :bmp, :cr2, :cr3, :dpx, :fdx, :flac, :gif, :heif, :heic,
                        :jpg, :json, :m3u, :mov, :mp3, :mp4, :m4a, :m4b, :m4p, :m4r, :m4v, :mpg,
                        :mpeg, :nef, :ogg, :pdf, :png, :psd, :rw2, :tif, :wav, :webp, :zip]
      )

      parser_class_names = parsers.map { |parser| parser.class.name }
      expect(parser_class_names.last).to eq 'FormatParser::MP3Parser'
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
