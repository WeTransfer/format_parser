require 'spec_helper'

describe FormatParser::ActiveStorage::BlobAnalyzer do
  let(:blob) { double(download: Random.new.bytes(512 * 1024)) }
  let(:analyzer) { described_class.new(blob) }

  describe 'self.accept?' do
    it 'should always return true' do
      expect(described_class.accept?(blob)).to eq(true)
    end
  end

  describe '#metadata' do
    it 'should call FormatParser#parse' do
      expect(FormatParser).to receive(:parse).with(instance_of(StringIO))

      analyzer.metadata
    end

    context 'when parsing an IO no parser can make sense of' do
      let(:blob) { double(download: Random.new.bytes(1)) }

      subject { analyzer.metadata }

      it { is_expected.to eq({}) }
    end

    context 'when parsing an IO recognised by parsers' do
      let(:fixture_path) { fixtures_dir + '/JPEG/too_many_APP1_markers_surrogate.jpg' }
      let(:blob) { double(download: File.open(fixture_path, 'rb').read) }

      subject { analyzer.metadata }

      it { is_expected.not_to eq({}) }
      it { is_expected.to have_key('nature') }
    end
  end
end
