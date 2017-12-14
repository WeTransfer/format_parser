class FormatParser::RemoteIO
  # @param uri[URI, String] the remote URL to obtain
  def initialize(uri)
    require 'net/http'
    @uri = URI(uri)
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
    available_size, body = request_range(http_range)
    @remote_size ||= available_size
    body
  end

  protected

  # Only used internally when reading the remote ZIP.
  #
  # @param range[Range] the HTTP range of data to fetch from remote
  # @return [String] the response body of the ranged request
  def request_range(range)
    request = Net::HTTP::Get.new(@uri)
    request.range = range
    http = Net::HTTP.start(@uri.hostname, @uri.port)
    response = http.request(request)

    range_header = response['Content-Range']
    raise "No range support at #{@url}" unless range_header

    # "Content-Range"=>"bytes 0-0/307404381"
    size = range_header[/\/(\d+)$/, 1].to_i
    [size, response.body]
  end

  # Reads the Content-Length and caches it
  def remote_size
    @remote_size ||= request_object_size
  end

  private

  def clamp(a, b, c)
    return a if b < a
    return c if b > c
    b
  end
end