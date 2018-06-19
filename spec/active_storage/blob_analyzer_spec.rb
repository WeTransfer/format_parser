require 'spec_helper'

describe FormatParser::ActiveStorage::BlobAnalyzer do
  let(:blob_service) { double }
  let(:blob) { double(key: 'blob_key', service: blob_service) }
  # let(:blob) { double(download: Random.new.bytes(512 * 1024)) }
  let(:analyzer) { described_class.new(blob) }

  describe 'self.accept?' do
    it 'should always return true' do
      expect(described_class.accept?(blob)).to eq(true)
    end
  end

  describe '#metadata' do
    it 'should call FormatParser#parse' do
      expect(FormatParser).to receive(:parse).with(instance_of(FormatParser::ActiveStorage::BlobIO))

      analyzer.metadata
    end

    context 'when parsing an IO no parser can make sense of' do
      before do
        allow(blob_service).to receive(:download_chunk) { Random.new.bytes(1) }
      end

      subject { analyzer.metadata }

      it { is_expected.to eq({}) }
    end

    context 'when parsing an IO recognised by parsers' do
      let(:fixture_path) { fixtures_dir + '/test.png' }

      before do
        allow(blob_service).to receive(:download_chunk) { File.open(fixture_path, 'rb').read }
      end

      subject { analyzer.metadata }

      it { is_expected.not_to eq({}) }
      it { is_expected.to have_key('nature') }
    end
  end
end
