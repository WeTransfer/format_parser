require 'spec_helper'

describe FormatParser::ActiveStorage::BlobAnalyzer do
  let(:blob_service) { double }
  let(:blob) { double(key: 'blob_key', service: blob_service) }
  let(:analyzer) { described_class.new(blob) }

  describe 'self.accept?' do
    it 'should always return true' do
      expect(described_class.accept?(blob)).to eq(true)
    end
  end

  describe '#metadata' do
    context 'internal method calls' do
      it 'should call FormatParser#parse' do
        expect(FormatParser).to receive(:parse).with(instance_of(FormatParser::ActiveStorage::BlobIO))

        analyzer.metadata
      end

      it 'should call FormatParser::ReadLimiter.read multiple times' do
        expect_any_instance_of(FormatParser::ReadLimiter).to receive(:read).at_least(:once)

        analyzer.metadata
      end

      it 'shoul;d call Care::IOWrapper.read multiple times' do
        expect_any_instance_of(Care::IOWrapper).to receive(:read).at_least(:once)

        analyzer.metadata
      end
    end

    context 'when parsing an IO no parser can make sense of' do
      subject { analyzer.metadata }

      before do
        allow(blob_service).to receive(:download_chunk) { Random.new.bytes(1) }
      end

      it { is_expected.to eq({}) }
    end

    context 'when parsing an IO recognised by parsers' do
      let(:fixture_path) { fixtures_dir + '/test.png' }
      subject { analyzer.metadata }

      before do
        allow(blob_service).to receive(:download_chunk) { File.open(fixture_path, 'rb').read }
      end

      it { is_expected.not_to eq({}) }
      it { is_expected.to have_key('nature') }
    end
  end
end
