require 'spec_helper'

describe Care do
  let(:source) { StringIO.new("Hello there, this is our little caching reader") }

  it 'performs correct reads at various offsets' do
    cache = Care.new(3)
    expect(cache.byteslice(source, 0, 3)).to eq("Hel")
    expect(cache.byteslice(source, 0, 7)).to eq("Hello t")
    expect(cache.byteslice(source, 1, 7)).to eq("ello th")
    expect(cache.byteslice(source, 11, 8)).to eq(", this i")
    expect(cache.byteslice(source, 12, 12)).to eq(" this is our")
    expect(cache.byteslice(source, 120, 12)).to be_nil
  end

  it 'fits all the reads into one if the input fits into one page' do
    expect(source).to receive(:read).at_most(2).times.and_call_original

    cache = Care.new(source.size)

    cache.byteslice(source, 0, 3)
    cache.byteslice(source, 11, 8)
    cache.byteslice(source, 190, 12)
    cache.byteslice(source, 290, 1)
    cache.byteslice(source, 890, 1)
  end

  it 'permits oversized reads' do
    cache = Care.new(4)
    expect(cache.byteslice(source, 0, 999)).to eq(source.string)
  end

  it 'returns nil with an empty input' do
    cache = Care.new(4)
    expect(cache.byteslice(StringIO.new(''), 0, 1)).to be_nil
  end
end
