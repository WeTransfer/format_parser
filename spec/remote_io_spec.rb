require 'spec_helper'

describe FormatParser::RemoteIO do
  it_behaves_like 'an IO object compatible with IOConstraint'

  it 'returns the partial content when the server supplies a 206 status' do
    url = 'https://images.invalid/img.jpg'
    response_body = 'This is the response'

    fake_resp = double(code: '206', body: response_body)
    allow(fake_resp).to receive(:[]).and_return('10-109/2577')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=10-109')
    )

    rio = described_class.new(url)
    rio.seek(10)
    read_result = rio.read(100)

    expect(read_result).to eq(response_body)
  end

  it 'returns the entire content when the server supplies the Content-Range response but sends a 200 status' do
    url = 'https://images.invalid/img.jpg'
    response_body = 'This is the response'

    fake_resp = double(code: '200', body: response_body)
    allow(fake_resp).to receive(:[]).and_return('10-109/2577')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=10-109')
    )

    rio = described_class.new(url)
    rio.seek(10)
    read_result = rio.read(100)

    expect(read_result).to eq(response_body)
  end

  it 'raises a specific error for all 4xx responses except 416' do
    url = 'https://images.invalid/img.jpg'

    fake_resp = double(headers: {}, code: '403', body: 'Please log in')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect { rio.read(100) }.to raise_error(/replied with a 403 and refused/)
  end

  it 'returns nil on a 416 response' do
    url = 'https://images.invalid/img.jpg'

    fake_resp = double(headers: {}, code: '416', body: 'You stepped off the ledge of the range')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect(rio.read(100)).to be_nil
  end

  it 'sets the status_code of the exception on a 4xx response from upstream' do
    url = 'https://images.invalid/img.jpg'

    fake_resp = double(headers: {}, code: '403', body: 'Please log in')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)
    expect { rio.read(100) }.to(raise_error { |e| expect(e.status_code).to eq(403) })
  end

  it 'returns a nil when the range cannot be satisfied and the response is 416' do
    url = 'https://images.invalid/img.jpg'

    fake_resp = double(headers: {}, code: '416', body: 'You jumped off the end of the file maam')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect(rio.read(100)).to be_nil
  end

  it 'does not overwrite size when the range cannot be satisfied and the response is 416' do
    url = 'https://images.invalid/img.jpg'

    fake_resp1 = double(code: '206', body: 'a')
    allow(fake_resp1).to receive(:[]).and_return('bytes 0-0/13')
    fake_resp2 = double(headers: {}, code: '416', body: 'You jumped off the end of the file maam')
    allow(Net::HTTP).to receive(:get_response).with(anything, a_hash_including('range' => 'bytes=0-0')).and_return(fake_resp1)
    allow(Net::HTTP).to receive(:get_response).with(anything, a_hash_including('range' => 'bytes=100-199')).and_return(fake_resp2)

    expect(Net::HTTP).to receive(:get_response)
      .with(
        an_object_satisfying { |uri| uri.to_s == url },
        a_hash_including('range' => 'bytes=0-0')
      )
      .ordered
    expect(Net::HTTP).to receive(:get_response)
      .with(
        an_object_satisfying { |uri| uri.to_s == url },
        a_hash_including('range' => 'bytes=100-199')
      )
      .ordered

    rio = described_class.new(url)
    rio.read(1)

    expect(rio.size).to eq(13)

    rio.seek(100)

    expect(rio.read(100)).to be_nil
    expect(rio.size).to eq(13)
  end

  it 'raises a specific error for all 5xx responses' do
    url = 'https://images.invalid/img.jpg'

    fake_resp = double(headers: {}, code: '502', body: 'Guru meditation')
    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect { rio.read(100) }.to raise_error(/replied with a 502 and we might want to retry/)
  end

  it 'maintains and exposes #pos' do
    url = 'https://images.invalid/img.jpg'

    rio = described_class.new(url)

    expect(rio.pos).to eq(0)

    fake_resp = double(code: '206', body: 'a')
    allow(fake_resp).to receive(:[]).and_return('bytes 0-0/13')

    allow(Net::HTTP).to receive(:get_response).and_return(fake_resp)

    expect(Net::HTTP).to receive(:get_response).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=0-0')
    )

    rio.read(1)
    expect(rio.pos).to eq(1)
  end
end
