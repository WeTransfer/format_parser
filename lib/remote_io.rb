# Acts as a wrapper for turning a given URL into an IO object
# you can read from and seek in. Uses Faraday under the hood
# to perform fetches, so if you apply Faraday configuration
# tweaks using `Faraday.default_connection = ...` these will
# take effect for these RemoteIO objects as well
class FormatParser::RemoteIO
  class UpstreamError < StandardError
    # @return Integer
    attr_reader :status_code
    def initialize(status_code, message)
      @status_code = status_code
      super(message)
    end
  end

  # Represents a failure that might be retried
  # (like a 5xx response or a timeout)
  class IntermittentFailure < UpstreamError
  end

  # Represents a failure that should not be retried
  # (like a 4xx response or a DNS resolution error)
  class InvalidRequest < UpstreamError
  end

  # @param uri[URI, String] the remote URL to obtain
  # @param headers[Hash] (optional) the HTTP headers to be used in the HTTP request
  def initialize(uri, headers: {})
    require 'faraday'
    require 'faraday_middleware/response/follow_redirects'
    @headers = headers
    @uri = uri
    @pos = 0
    @remote_size = false
  end

  # Emulates IO#seek
  def seek(offset)
    @pos = offset
    0 # always return 0
  end

  # Emulates IO#pos
  def pos
    @pos
  end

  # Emulates IO#size.
  #
  # @return [Integer] the size of the remote resource
  def size
    raise 'Remote size not yet obtained, need to perform at least one read() to retrieve it' unless @remote_size
    @remote_size
  end

  # Emulates IO#read, but requires the number of bytes to read
  # The read will be limited to the
  # size of the remote resource relative to the current offset in the IO,
  # so if you are at offset 0 in the IO of size 10, doing a `read(20)`
  # will only return you 10 bytes of result, and not raise any exceptions.
  #
  # @param n_bytes[Fixnum, nil] how many bytes to read, or `nil` to read all the way to the end
  # @return [String] the read bytes
  def read(n_bytes)
    http_range = (@pos..(@pos + n_bytes - 1))
    maybe_size, maybe_body = Measurometer.instrument('format_parser.RemoteIO.read') { request_range(http_range) }
    if maybe_size && maybe_body
      @remote_size = maybe_size
      @pos += maybe_body.bytesize
      maybe_body.force_encoding(Encoding::ASCII_8BIT)
    end
  end

  protected

  # Only used internally when reading the remote file
  #
  # @param range[Range] the HTTP range of data to fetch from remote
  # @return [String] the response body of the ranged request
  def request_range(range)
    # We use a GET and not a HEAD request followed by a GET because
    # S3 does not allow HEAD requests if you only presigned your URL for GETs, so we
    # combine the first GET of a segment and retrieving the size of the resource
    conn = Faraday.new(headers: @headers) do |faraday|
      faraday.use FaradayMiddleware::FollowRedirects
      # we still need the default adapter, more details: https://blog.thecodewhisperer.com/permalink/losing-time-to-faraday
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get(@uri, nil, range: 'bytes=%d-%d' % [range.begin, range.end])

    case response.status
    when 200
      # S3 returns 200 when you request a Range that is fully satisfied by the entire object,
      # we take that into account here. Also, for very tiny responses (and also for empty responses)
      # the responses are going to be 200 which does not mean we cannot proceed
      # To have a good check for both of these conditions we need to know whether the ranges overlap fully
      response_size = response.body.bytesize
      requested_range_size = range.end - range.begin + 1
      if response_size > requested_range_size
        error_message = [
          "We requested #{requested_range_size} bytes, but the server sent us more",
          "(#{response_size} bytes) - it likely has no `Range:` support.",
          "The error occurred when talking to #{@uri})"
        ]
        raise InvalidRequest.new(response.status, error_message.join("\n"))
      end
      [response_size, response.body]
    when 206
      # Figure out of the server supports content ranges, if it doesn't we have no
      # business working with that server
      range_header = response.headers['Content-Range']
      raise InvalidRequest.new(response.status, "The server replied with 206 status but no Content-Range at #{@uri}") unless range_header

      # "Content-Range: bytes 0-0/307404381" is how the response header is structured
      size = range_header[/\/(\d+)$/, 1].to_i

      # If we request a _larger_ range than what can be satisfied by the server,
      # the response is going to only contain what _can_ be sent and the status is also going
      # to be 206
      return [size, response.body]
    when 416
      # We return `nil` if we tried to read past the end of the IO,
      # which satisfies the Ruby IO convention. The caller should deal with `nil` being the result of a read()
      # S3 will also handily _not_ supply us with the Content-Range of the actual resource, so we
      # cannot hint size with this response - at lease not when working with S3
      return
    when 500..599
      Measurometer.increment_counter('format_parser.RemoteIO.upstream50x_errors', 1)
      raise IntermittentFailure.new(response.status, "Server at #{@uri} replied with a #{response.status} and we might want to retry")
    else
      Measurometer.increment_counter('format_parser.RemoteIO.invalid_request_errors', 1)
      raise InvalidRequest.new(response.status, "Server at #{@uri} replied with a #{response.status} and refused our request")
    end
  end
end
