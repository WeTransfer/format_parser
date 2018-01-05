require 'spec_helper'

describe "ReadLimiter" do
  let(:io) { StringIO.new(Random.new.bytes(1024)) }

  it 'implements the complete subset of IOConstraint' do
    reader = FormatParser::ReadLimiter.new(io)
    methods_not_covered = Set.new(FormatParser::IOConstraint.public_instance_methods) - Set.new(reader.public_methods)
    expect(methods_not_covered).to be_empty
  end

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

end
