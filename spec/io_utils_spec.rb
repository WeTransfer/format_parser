require 'spec_helper'
require 'securerandom'
describe "IOUtils" do
  let(:io) {File.open(__dir__ + '/fixtures/test.jpg', 'rb')}
  include FormatParser::IOUtils 
  
  it 'raises if the requested bytes are past the EOF' do
    io.seek(268118) # Seek to the actual end of the file
    expect {
      safe_read(io, 10)
    }.to raise_error(/We wanted to read 10 bytes from the IO, but the IO is at EOF/)
  end

  it 'raises if we ask for more bytes than are available' do
    expect {
      safe_read(io, 1_000_000)
    }.to raise_error(/We wanted to read 1000000 bytes from the IO, but we got 268118 instead/)
  end  
end