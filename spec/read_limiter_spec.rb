require 'spec_helper'

describe "ReadLimiter" do
  let(:io) { StringIO.new(Random.new.bytes(1024)) }

  it 'does not enforce any limits with default arguments' do
    reader = FormatParser::ReadLimiter.new(io)
    2048.times { reader.seek(1) }
    2048.times { reader.read(4) }
  end

  it 'enforces the number of seeks' do
    reader = FormatParser::ReadLimiter.new(io, max_seeks: 4)
    4.times { reader.seek(1) }
    expect {
      reader.seek(1)
    }.to raise_error(/Seek budget exceeded/)
  end

  it 'enforces the number of reads' do
    reader = FormatParser::ReadLimiter.new(io, max_reads: 4)
    4.times { reader.read(1) }
    expect {
      reader.read(1)
    }.to raise_error(/calls exceeded \(4 max\)/)
  end

  it 'enforces the number of bytes read' do
    reader = FormatParser::ReadLimiter.new(io, max_bytes: 512)
    reader.read(512)
    expect {
      reader.read(1)
    }.to raise_error(/bytes budget \(512\) exceeded/)
  end

  it 'enforces the number of bytes read with readbyte' do
    reader = FormatParser::ReadLimiter.new(io, max_bytes: 512)
    reader.readbyte(num_bytes_to_read: 512)
    expect {
      reader.readbyte(num_bytes_to_read: 1)
    }.to raise_error(/bytes budget \(512\) exceeded/)
  end

  it 'enforces the number of reads with readbyte' do
    reader = FormatParser::ReadLimiter.new(io, max_reads: 4)
    4.times { reader.readbyte(num_bytes_to_read: 1) }
    expect {
      reader.readbyte(num_bytes_to_read: 1)
    }.to raise_error(/calls exceeded \(4 max\)/)
  end
end
