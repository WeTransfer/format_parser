require 'spec_helper'

describe FormatParser::RemoteIO do
  it_behaves_like 'an IO object compatible with IOConstraint'

  # 2XX

  context 'when the response code is 200 (OK)' do
    context 'when the response size does not exceed the requested range' do
      it 'returns the entire response body' do
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
    end

    context 'when the response size exceeds the requested range' do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'
        response = Net::HTTPOK.new('2', '200', 'OK')
        allow(response).to receive(:body).and_return('This response is way longer than 10 bytes.')

        allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
        allow(Net::HTTP).to receive(:request_get).and_return(response)

        expect(Net::HTTP).to receive(:request_get).with(
          an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
          a_hash_including('range' => 'bytes=10-19')
        )

        rio = described_class.new(url)
        rio.seek(10)
        expect { rio.read(10) }.to raise_error(
          "We requested 10 bytes, but the server sent us more\n"\
          "(42 bytes) - it likely has no `Range:` support.\n"\
          "The error occurred when talking to #{url}"
        )
      end
    end
  end

  context 'when the response status code is 206 (Partial Content)' do
    context 'when the Content-Range header is present' do
      it 'returns the response body' do
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

      it 'maintains and exposes pos' do
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

    context 'when the Content-Range header is not present' do
      it 'raises an error' do
        url = 'https://images.invalid/img.jpg'
        response = Net::HTTPPartialContent.new('2', '206', 'Partial Content')

        allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
        allow(Net::HTTP).to receive(:request_get).and_return(response)

        expect(Net::HTTP).to receive(:request_get).with(
          an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
          a_hash_including('range' => 'bytes=10-109')
        )

        rio = described_class.new(url)
        rio.seek(10)
        expect { rio.read(100) }.to raise_error("The server replied with 206 status but no Content-Range at #{url}")
      end
    end
  end

  # 3XX

  context 'when the response code is 301 (Moved Permanently), 302 (Found), 303 (See Other), 307 (Temporary Redirect) or  308 (Permanent Redirect)' do
    context 'when the location header is present and the redirect limit is not exceeded' do
      context 'when the location is absolute' do
        it 'redirects to the specified location, without the Authorization header' do
          initial_url = 'https://my_images.invalid/my_image'
          redirect_url = 'https://images.invalid/img.jpg'
          final_response = Net::HTTPOK.new('2', '200', 'OK')
          allow(final_response).to receive(:body).and_return('Response body')

          %w[301 302 303 307 308].each do |code|
            redirect_response = Net::HTTPFound.new('2', code, 'Redirect')
            redirect_response['location'] = redirect_url

            allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(redirect_response, final_response)
            allow(Net::HTTP).to receive(:request_get).and_return(redirect_response, final_response)

            expect(Net::HTTP).to receive(:request_get).with(
              an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == initial_url },
              a_hash_including('range' => 'bytes=10-109', 'Authorization' => 'token')
            ).ordered
            expect(Net::HTTP).to receive(:request_get).with(
              an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == redirect_url },
              a_hash_including('range' => 'bytes=10-109').and(excluding('Authorization'))
            ).ordered

            rio = described_class.new(initial_url, headers: { 'Authorization' => 'token' })
            rio.seek(10)
            read_result = rio.read(100)

            expect(read_result).to eq(final_response.body)
          end
        end
      end

      context 'when the location is relative' do
        it 'redirects to the specified location under the same host, with the same Authorization header' do
          initial_url = 'https://images.invalid/my_image'
          redirect_url = '/img.jpg'
          final_response = Net::HTTPOK.new('2', '200', 'OK')
          allow(final_response).to receive(:body).and_return('Response body')

          %w[301 302 303 307 308].each do |code|
            redirect_response = Net::HTTPFound.new('2', code, 'Redirect')
            redirect_response['location'] = redirect_url

            allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(redirect_response, final_response)
            allow(Net::HTTP).to receive(:request_get).and_return(redirect_response, final_response)

            expect(Net::HTTP).to receive(:request_get).with(
              an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == initial_url },
              a_hash_including('range' => 'bytes=10-109', 'Authorization' => 'token')
            ).ordered
            expect(Net::HTTP).to receive(:request_get).with(
              an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == 'https://images.invalid/img.jpg' },
              a_hash_including('range' => 'bytes=10-109', 'Authorization' => 'token')
            ).ordered

            rio = described_class.new(initial_url, headers: { 'Authorization' => 'token' })
            rio.seek(10)
            read_result = rio.read(100)

            expect(read_result).to eq(final_response.body)
          end
        end
      end
    end

    context 'when the location header is not present' do
      it 'raises an error' do
        url = 'https://images.invalid/my_image'

        %w[301 302 303 307 308].each do |code|
          response = Net::HTTPFound.new('2', code, 'Redirect')

          allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
          allow(Net::HTTP).to receive(:request_get).and_return(response)

          expect(Net::HTTP).to receive(:request_get).with(
            an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
            a_hash_including('range' => 'bytes=10-109')
          )

          rio = described_class.new(url)
          rio.seek(10)

          expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code}, indicating redirection; however, the location header was empty.")
        end
      end
    end

    context 'when the redirect limit is exceeded' do
      it 'raises an error' do
        url = 'https://images.invalid/my_image'
        redirect_url = 'https://images.invalid/img.jpg'

        {
          '301' => Net::HTTPMovedPermanently,
          '302' => Net::HTTPFound,
          '303' => Net::HTTPSeeOther,
          '307' => Net::HTTPTemporaryRedirect,
          '308' => Net::HTTPPermanentRedirect,
        }.each do |code, response_class|
          response = response_class.new('2', code, 'Redirect')
          response['location'] = redirect_url

          allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
          allow(Net::HTTP).to receive(:request_get).and_return(response)

          expect(Net::HTTP).to receive(:request_get).with(
            an_object_satisfying { |uri| URI::HTTPS === uri && uri.to_s == url },
            a_hash_including('range' => 'bytes=10-109')
          )

          rio = described_class.new(url)
          rio.seek(10)
          expect { rio.read(100) }.to raise_error("Too many redirects; last one to: #{redirect_url}")
        end
      end
    end
  end

  # 4XX

  context 'when the response status code is 416 (Range Not Satisfiable)' do
    it 'returns nil' do
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

    it 'does not change pos or size' do
      url = 'https://images.invalid/img.jpg'
      first_response = Net::HTTPPartialContent.new('2', '206', 'Partial Content')
      first_response['Content-Range'] = 'bytes 0-0/13'
      allow(first_response).to receive(:body).and_return('Response body')
      second_response = Net::HTTPRangeNotSatisfiable.new('2', '416', 'Range Not Satisfiable')

      allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(first_response, second_response)
      allow(Net::HTTP).to receive(:request_get).and_return(first_response, second_response)

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
      rio.read(100)

      expect(rio.pos).to eq(100)
      expect(rio.size).to eq(13)
    end
  end

  context 'when the response status code is 4xx' do
    it 'raises an error' do
      url = 'https://images.invalid/img.jpg'
      [*'400'..'415', *'417'..'499'].each do |code|
        response = Net::HTTPClientError.new('2', code, 'Client Error')

        allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
        allow(Net::HTTP).to receive(:request_get).and_return(response)

        expect(Net::HTTP).to receive(:request_get).with(
          an_object_satisfying { |uri| uri.to_s == url },
          a_hash_including('range' => 'bytes=100-199')
        )

        rio = described_class.new(url)
        rio.seek(100)

        expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code} and refused our request")
      end
    end
  end

  # 5XX

  context 'when the response status code is 5xx' do
    it 'raises an error' do
      url = 'https://images.invalid/img.jpg'
      ('500'..'599').each do |code|
        response = Net::HTTPServerError.new('2', code, 'Server Error')

        allow(Net::HTTP).to receive(:start).and_yield(Net::HTTP).and_return(response)
        allow(Net::HTTP).to receive(:request_get).and_return(response)

        expect(Net::HTTP).to receive(:request_get).with(
          an_object_satisfying { |uri| uri.to_s == url },
          a_hash_including('range' => 'bytes=100-199')
        )

        rio = described_class.new(url)
        rio.seek(100)

        expect { rio.read(100) }.to raise_error("Server at #{url} replied with a #{code} and we might want to retry")
      end
    end
  end
end
