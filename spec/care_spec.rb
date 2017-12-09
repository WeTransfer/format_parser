require 'spec_helper'

describe Care do
  describe Care::Cache do
    let(:source) { StringIO.new("Hello there, this is our little caching reader") }

    it 'performs correct reads at various offsets' do
      cache = Care::Cache.new(3)
      expect(cache.byteslice(source, 0, 3)).to eq("Hel")
      expect(cache.byteslice(source, 0, 7)).to eq("Hello t")
      expect(cache.byteslice(source, 1, 7)).to eq("ello th")
      expect(cache.byteslice(source, 11, 8)).to eq(", this i")
      expect(cache.byteslice(source, 12, 12)).to eq(" this is our")
      expect(cache.byteslice(source, 120, 12)).to be_nil
    end

    it 'fits all the reads into one if the input fits into one page' do
      expect(source).to receive(:read).at_most(2).times.and_call_original

      cache = Care::Cache.new(source.size)

      cache.byteslice(source, 0, 3)
      cache.byteslice(source, 11, 8)
      cache.byteslice(source, 190, 12)
      cache.byteslice(source, 290, 1)
      cache.byteslice(source, 890, 1)
    end

    it 'permits oversized reads' do
      cache = Care::Cache.new(4)
      expect(cache.byteslice(source, 0, 999)).to eq(source.string)
    end

    it 'returns nil with an empty input' do
      cache = Care::Cache.new(4)
      expect(cache.byteslice(StringIO.new(''), 0, 1)).to be_nil
    end
  end

  describe Care::IOWrapper do
    it 'forwards calls to read() to the Care and adjusts internal offsets' do
      fake_cache_class = Class.new do
        attr_reader :recorded_calls
        def byteslice(io, at, n_bytes)
          @recorded_calls ||= []
          @recorded_calls << [io, at, n_bytes]
          # Pretend reads always succeed and return the requisite number of bytes
          "x" * n_bytes
        end
      end

      cache_double = fake_cache_class.new
      io_double = double('IO')

      subject = Care::IOWrapper.new(io_double, cache_double)

      subject.read(2)
      subject.read(3)
      subject.seek(11)
      subject.read(5)

      expect(cache_double.recorded_calls).to be_kind_of(Array)
      first, second, third = *cache_double.recorded_calls
      expect(first).to eq([io_double,  0, 2])
      expect(second).to eq([io_double, 2, 3])
      expect(third).to eq([io_double,  11, 5])
    end
  end
end
