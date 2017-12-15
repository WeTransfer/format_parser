class FormatParser::RemoteIO

  # Represents a failure that might be retried
  # (like a 5xx response or a timeout)
  class IntermittentFailure < StandardError
  end

  # Represents a failure that should not be retried
  # (like a 4xx response or a DNS resolution error)
  class InvalidRequest < StandardError
  end

  # @param uri[URI, String] the remote URL to obtain
  def initialize(uri)
    require 'faraday'
    @uri = uri
    @pos = 0
    @remote_size = false
  end

  # Emulates IO#seek
  def seek(offset)
    @pos = offset
    0 # always return 0
  end

  # Emulates IO#size.
  #
  # @return [Fixnum] the size of the remote resource
  def size
    raise "Remote size not yet obtained, need to perform at least one read() to get it" unless @remote_size
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
    @remote_size, body = request_range(http_range)
    body.force_encoding(Encoding::BINARY) if body
    body
  end

  protected

  # Only used internally when reading the remote file
  #
  # @param range[Range] the HTTP range of data to fetch from remote
  # @return [String] the response body of the ranged request
  def request_range(range)
    # We use a GET and not a HEAD request followed by a GET because
    # S3 does not allow HEAD requests if you only presigned your URL for GETs
    response = Faraday.get(@uri, nil, range: "bytes=%d-%d" % [range.begin, range.end])

    # Figure out of the server supports content ranges, if it doesn't we have no
    # business working with that server
    range_header = response['Content-Range']
    raise InvalidRequest, "No range support at #{@url}" unless range_header

    # "Content-Range: bytes 0-0/307404381" is how the response header is structured
    size = range_header[/\/(\d+)$/, 1].to_i

    case response.status
    when 200, 206
      # S3 returns 200 when you request a Range that is fully satisfied by the entire object,
      # we take that into account here. For other servers, 206 is the expected response code
      return [size, response.body]
    when 416
      # We return `nil` as the body if we tried to read past the end of the IO,
      # which satisfies the Ruby IO convention. The caller should deal with `nil` being the result of a read() 
      return [size, nil]
    when 500..599
      raise IntermittentFailure, "Server at #{@url} replied with a #{response.status} and we might want to retry"
    else
      raise InvalidRequest, "Server at #{@url} replied with a #{response.status} and refused our request"
    end
  end
end
