require 'spec_helper'

describe FormatParser::RemoteIO do
  it_behaves_like 'an IO object compatible with IOConstraint'

  it 'returns the partial content when the server supplies a 206 status' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {'Content-Range': '10-109/2577'}, status: 206, body: 'This is the response')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=10-109').and_return(fake_resp)

    rio.seek(10)
    read_result = rio.read(100)
    expect(read_result).to eq('This is the response')
  end

  it 'returns the entire content when the server supplies the Content-Range response but sends a 200 status' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {'Content-Range': '10-109/2577'}, status: 200, body: 'This is the response')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=10-109').and_return(fake_resp)

    rio.seek(10)
    read_result = rio.read(100)
    expect(read_result).to eq('This is the response')
  end

  it 'raises a specific error for all 4xx responses except 416' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {}, status: 403, body: 'Please log in')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=100-199').and_return(fake_resp)

    rio.seek(100)
    expect { rio.read(100) }.to raise_error(/replied with a 403 and refused/)
  end

  it 'returns a nil when the range cannot be satisfied and the response is 416' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {}, status: 416, body: 'You jumped off the end of the file maam')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=100-199').and_return(fake_resp)

    rio.seek(100)
    expect(rio.read(100)).to be_nil
  end

  it 'does not overwrite size when the range cannot be satisfied and the response is 416' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {'Content-Range': 'bytes 0-0/13'}, status: 206, body: 'a')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=0-0').and_return(fake_resp)
    rio.read(1)

    expect(rio.size).to eq(13)

    fake_resp = double(headers: {}, status: 416, body: 'You jumped off the end of the file maam')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=100-199').and_return(fake_resp)

    rio.seek(100)
    expect(rio.read(100)).to be_nil

    expect(rio.size).to eq(13)
  end

  it 'raises a specific error for all 5xx responses' do
    rio = described_class.new('https://images.invalid/img.jpg')

    fake_resp = double(headers: {}, status: 502, body: 'Guru meditation')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=100-199').and_return(fake_resp)

    rio.seek(100)
    expect { rio.read(100) }.to raise_error(/replied with a 502 and we might want to retry/)
  end

  it 'maintains and exposes #pos' do
    rio = described_class.new('https://images.invalid/img.jpg')

    expect(rio.pos).to eq(0)

    fake_resp = double(headers: {'Content-Range': 'bytes 0-0/13'}, status: 206, body: 'a')
    expect(Faraday).to receive(:get).with('https://images.invalid/img.jpg', nil, range: 'bytes=0-0').and_return(fake_resp)
    rio.read(1)

    expect(rio.pos).to eq(1)
  end
end
