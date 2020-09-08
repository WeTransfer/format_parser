require 'spec_helper'

describe FormatParser::ActiveStorage::BlobIO do
  let(:blob_service) { double }
  let(:blob) { double(key: 'blob_key', service: blob_service, byte_size: 43000) }
  let(:io) { described_class.new(blob) }
  let(:fixture_path) { fixtures_dir + '/test.png' }

  it_behaves_like 'an IO object compatible with IOConstraint'

  describe '#read' do
    it 'reads io using download_chunk from ActiveStorage#Service' do
      allow(blob_service).to receive(:download_chunk) { 'a' }

      expect(io.read(1)).to eq('a')
    end

    it 'updates #pos on read' do
      allow(blob_service).to receive(:download_chunk) { 'a' }

      expect { io.read(1) }.to change { io.pos }.from(0).to(1)
    end
  end

  describe '#seek' do
    it 'updates @pos' do
      expect { io.seek(10) }.to change { io.pos }.from(0).to(10)
    end
  end

  describe '#size' do
    it 'returns the size of the blob byte_size' do
      expect(io.size).to eq(blob.byte_size)
    end
  end
end
