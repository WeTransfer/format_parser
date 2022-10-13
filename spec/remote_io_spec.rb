require 'spec_helper'

describe FormatParser::RemoteIO do
  it_behaves_like 'an IO object compatible with IOConstraint'

  it 'returns the partial content when the server supplies a 206 status' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPPartialContent.new('2', '206', 'Partial Content')
    response['Content-Range'] = '10-109/2577'
    allow(response).to receive(:body).and_return('Response body')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
      a_hash_including('range' => 'bytes=10-109')
    )

    rio = described_class.new(url)
    rio.seek(10)
    read_result = rio.read(100)

    expect(read_result).to eq(response.body)
  end

  it 'returns the entire content when the server supplies the Content-Range response but sends a 200 status' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPOK.new('2', '200', 'OK')
    allow(response).to receive(:body).and_return('Response body')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
      a_hash_including('range' => 'bytes=10-109')
    )

    rio = described_class.new(url)
    rio.seek(10)
    read_result = rio.read(100)

    expect(read_result).to eq(response.body)
  end

  it 'raises a specific error for all 4xx responses except 416' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPForbidden.new('2', '403', 'Forbidden')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect { rio.read(100) }.to raise_error(/replied with a 403 and refused/)
  end

  it 'returns nil on a 416 response' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPRangeNotSatisfiable.new('2', '416', 'Range Not Satisfiable')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect(rio.read(100)).to be_nil
  end

  it 'sets the status_code of the exception on a 4xx response from upstream' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPForbidden.new('2', '403', 'Forbidden')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)
    expect { rio.read(100) }.to(raise_error { |e| expect(e.status_code).to eq(403) })
  end

  it 'returns a nil when the range cannot be satisfied and the response is 416' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPRangeNotSatisfiable.new('2', '416', 'Range Not Satisfiable')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect(rio.read(100)).to be_nil
  end

  it 'does not overwrite size when the range cannot be satisfied and the response is 416' do
    url = 'https://images.invalid/img.jpg'
    response_1 = Net::HTTPPartialContent.new('2', '206', 'Partial Content')
    response_1['Content-Range'] = 'bytes 0-0/13'
    allow(response_1).to receive(:body).and_return('Response body')
    response_2 = Net::HTTPRangeNotSatisfiable.new('2', '416', 'Range Not Satisfiable')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response_1, response_2)
    allow(Net::HTTP).to receive(:request_get).and_return(response_1, response_2)

    expect(Net::HTTP).to receive(:request_get)
      .with(
        an_object_satisfying { |uri| uri.to_s == url },
        a_hash_including('range' => 'bytes=0-0')
      )
      .ordered
    expect(Net::HTTP).to receive(:request_get)
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
    response = Net::HTTPBadGateway.new('2', '502', 'Bad Gateway')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=100-199')
    )

    rio = described_class.new(url)
    rio.seek(100)

    expect { rio.read(100) }.to raise_error(/replied with a 502 and we might want to retry/)
  end

  it 'maintains and exposes #pos' do
    url = 'https://images.invalid/img.jpg'
    response = Net::HTTPPartialContent.new('2', '206', 'Partial Content')
    response['Content-Range'] = 'bytes 0-0/13'
    allow(response).to receive(:body).and_return('a')

    allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
    allow(Net::HTTP).to receive(:request_get).and_return(response)

    expect(Net::HTTP).to receive(:request_get).with(
      an_object_satisfying { |uri| uri.to_s == url },
      a_hash_including('range' => 'bytes=0-0')
    )

    rio = described_class.new(url)
    expect(rio.pos).to eq(0)
    rio.read(1)
    expect(rio.pos).to eq(1)
  end
end
