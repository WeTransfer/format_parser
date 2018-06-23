require 'spec_helper'

describe FormatParser::ActiveStorage::BlobIO do
  let(:blob_service) { double }
  let(:blob) { double(key: 'blob_key', service: blob_service) }
  let(:io) { described_class.new(blob) }
  let(:fixture_path) { fixtures_dir + '/test.png' }

  it_behaves_like 'an IO object compatible with IOConstraint'

  it 'maintains and exposes #pos' do
    expect(io.pos).to eq(0)

    allow(blob_service).to receive(:download_chunk) { 'a' }

    io.read(1)

    expect(io.pos).to eq(1)
  end

  describe '#read' do
    it 'raise error when trying to fetch non existent key' do
      allow(blob).to receive(:key) { 'invalid_key' }
      allow(blob_service).to receive(:download_chunk).with(blob.key, (0..0)).and_raise(Errno::ENOENT)

      expect { io.read(1) }.to raise_error(ArgumentError, "Key #{blob.key} does not exist")
    end

    it 'return the whole file when reading past the end of file' do
      allow(blob_service).to receive(:download_chunk).with(blob.key, (0..9_999)).and_return('a' * 10)

      io.read(100_00)

      expect(io.size).to eq(10)
    end

    context 'invalid range' do
      it 'raise error with -ve range start' do
      end

      it 'raise when range start greater than range end' do
        n_bytes = -1
        range_start = 0 # @pos
        range_end = range_start + n_bytes - 1

        expect { io.read(n_bytes) }.to raise_error(ArgumentError, "Invalid range from #{range_start} to #{range_end}")
      end
    end
  end
end
