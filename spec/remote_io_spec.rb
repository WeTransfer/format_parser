require 'spec_helper'

describe FormatParser::RemoteIO do
  it_behaves_like 'an IO object compatible with IOConstraint'

  # 2XX

  context 'when the response code is 200 (OK)' do
    context 'when the response size does not exceed the requested range' do
      it 'returns the entire response body' do
        url = 'https://images.invalid/img.jpg'
        body = 'response body'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=10-109' })
          .to_return(body: body, status: 200)

        rio = described_class.new(url)
        rio.seek(10)
        read_result = rio.read(100)

        expect(read_result).to eq(body)
        expect(stub).to have_been_requested
      end
    end

    context 'when the response size exceeds the requested range' do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'
        body = 'This response is way longer than 10 bytes.'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=10-19' })
          .to_return(body: body, status: 200)

        rio = described_class.new(url)
        rio.seek(10)

        expect { rio.read(10) }.to raise_error(
          "We requested 10 bytes, but the server sent us more\n"\
          "(42 bytes) - it likely has no `Range:` support.\n"\
          "The error occurred when talking to #{url}"
        )
        expect(stub).to have_been_requested
      end
    end
  end

  context 'when the response status code is 206 (Partial Content)' do
    context 'when the Content-Range header is present' do
      it 'returns the response body' do
        url = 'https://images.invalid/img.jpg'
        body = 'response body'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=10-109' })
          .to_return(body: body, headers: { 'Content-Range' => '10-109/2577' }, status: 206)

        rio = described_class.new(url)
        rio.seek(10)
        read_result = rio.read(100)

        expect(read_result).to eq(body)
        expect(stub).to have_been_requested
      end

      it 'maintains and exposes pos' do
        url = 'https://images.invalid/img.jpg'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=0-0' })
          .to_return(body: 'a', headers: { 'Content-Range' => '0-0/13' }, status: 206)

        rio = described_class.new(url)

        expect(rio.pos).to eq(0)

        rio.read(1)

        expect(rio.pos).to eq(1)
        expect(stub).to have_been_requested
      end
    end

    context 'when the Content-Range header is not present' do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=10-109' })
          .to_return(status: 206)

        rio = described_class.new(url)
        rio.seek(10)

        expect { rio.read(100) }.to raise_error("The server replied with 206 status but no Content-Range at #{url}")
        expect(stub).to have_been_requested
      end
    end
  end

  # 3XX

  [301, 302, 303, 307, 308].each do |code|
    context "when the response code is #{code}" do
      context 'when the location header is present and the redirect limit is not exceeded' do
        context 'when the location is absolute' do
          it 'redirects to the specified location, without the Authorization header' do
            redirecting_url = 'https://my_images.invalid/my_image'
            destination_url = 'https://images.invalid/img.jpg'
            body = 'response body'

            redirect_stub = stub_request(:get, redirecting_url)
              .with(headers: { 'Authorization' => 'token', 'range' => 'bytes=10-109' })
              .to_return(headers: { 'location' => destination_url }, status: code)
            destination_stub = stub_request(:get, destination_url)
              .with { |request| request.headers['Range'] == 'bytes=10-109' && !request.headers.key?('Authorization') }
              .to_return(body: body, status: 200)

            rio = described_class.new(redirecting_url, headers: { 'Authorization' => 'token' })
            rio.seek(10)
            read_result = rio.read(100)

            expect(read_result).to eq(body)
            expect(redirect_stub).to have_been_requested
            expect(destination_stub).to have_been_requested
          end
        end

        context 'when the location is relative' do
          it 'redirects to the specified location under the same host, with the same Authorization header' do
            host = 'https://images.invalid'
            redirecting_path = '/my_image'
            redirecting_url = host + redirecting_path
            destination_path = '/img.jpg'
            destination_url = host + destination_path
            body = 'response body'

            redirect_stub = stub_request(:get, redirecting_url)
              .with(headers: { 'Authorization' => 'token', 'range' => 'bytes=10-109' })
              .to_return(headers: { 'location' => destination_path }, status: code)
            destination_stub = stub_request(:get, destination_url)
              .with(headers: { 'Authorization' => 'token', 'range' => 'bytes=10-109' })
              .to_return(body: body, status: 200)

            rio = described_class.new(redirecting_url, headers: { 'Authorization' => 'token' })
            rio.seek(10)
            read_result = rio.read(100)

            expect(read_result).to eq(body)
            expect(redirect_stub).to have_been_requested
            expect(destination_stub).to have_been_requested
          end
        end
      end

      context 'when the location header is not present' do
        it 'raises an error' do
          url = 'https://images.invalid/my_image'

          stub = stub_request(:get, url)
            .with(headers: { 'range' => 'bytes=10-109' })
            .to_return(status: code)

          rio = described_class.new(url)
          rio.seek(10)

          expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code}, indicating redirection; however, the location header was empty.")
          expect(stub).to have_been_requested
        end
      end

      context 'when the redirect limit is exceeded' do
        it 'raises an error' do
          redirecting_url = 'https://images.invalid/my_image'
          destination_url = 'https://images.invalid/img.jpg'

          stub = stub_request(:get, /https:\/\/images\.invalid.*/)
            .with(headers: { 'range' => 'bytes=10-109' })
            .to_return(headers: { 'location' => destination_url }, status: code)

          rio = described_class.new(redirecting_url)
          rio.seek(10)

          expect { rio.read(100) }.to raise_error("Too many redirects; last one to: #{destination_url}")
          expect(stub).to have_been_requested.times(4)
        end
      end
    end
  end

  # 4XX

  context 'when the response status code is 416 (Range Not Satisfiable)' do
    it 'returns nil' do
      url = 'https://images.invalid/img.jpg'

      stub = stub_request(:get, url)
        .with(headers: { 'range' => 'bytes=100-199' })
        .to_return(status: 416)

      rio = described_class.new(url)
      rio.seek(100)

      expect(rio.read(100)).to be_nil
      expect(stub).to have_been_requested
    end

    it 'does not change pos or size' do
      url = 'https://images.invalid/img.jpg'

      stub = stub_request(:get, url)
        .with(headers: { 'range' => 'bytes=0-0' })
        .to_return(body: 'response body', headers: { 'Content-Range' => 'bytes 0-0/13' }, status: 206)

      rio = described_class.new(url)
      rio.read(1)

      expect(rio.size).to eq(13)
      expect(stub).to have_been_requested

      stub = stub_request(:get, url)
        .with(headers: { 'range' => 'bytes=100-199' })
        .to_return(status: 416)

      rio.seek(100)
      rio.read(100)

      expect(rio.pos).to eq(100)
      expect(rio.size).to eq(13)
      expect(stub).to have_been_requested
    end
  end

  [*400..415, *417..499].each do |code|
    context "when the response status code is #{code}" do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=100-199' })
          .to_return(status: code)

        rio = described_class.new(url)
        rio.seek(100)

        expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code} and refused our request")
        expect(stub).to have_been_requested
      end
    end
  end

  # 5XX
  (500..599).each do |code|
    context "when the response status code is #{code}" do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'

        stub = stub_request(:get, url)
          .with(headers: { 'range' => 'bytes=100-199' })
          .to_return(status: code)

        rio = described_class.new(url)
        rio.seek(100)

        expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code} and we might want to retry")
        expect(stub).to have_been_requested
      end
    end
  end
end
