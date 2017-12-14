class FormatParser::RemoteIO
  # @param fetcher[#request_object_size, #request_range] an object that perform fetches
  def initialize(uri)
    require 'net/http'
    
    @uri = URI(uri)
    @pos = 0
    @remote_size = false
  end

  # Emulates IO#seek
  def seek(offset, mode = IO::SEEK_SET)
    raise "Unsupported read mode #{mode}" unless mode == IO::SEEK_SET
    @remote_size ||= request_object_size
    @pos = clamp(0, offset, @remote_size)
    0 # always return 0!
  end

  # Emulates IO#size.
  #
  # @return [Fixnum] the size of the remote resource
  def size
    @remote_size ||= request_object_size
  end

  # Emulates IO#read, but requires the number of bytes to read
  # The read will be limited to the
  # size of the remote resource relative to the current offset in the IO,
  # so if you are at offset 0 in the IO of size 10, doing a `read(20)`
  # will only return you 10 bytes of result, and not raise any exceptions.
  #
  # @param n_bytes[Fixnum, nil] how many bytes to read, or `nil` to read all the way to the end
  # @return [String] the read bytes
  def read(n_bytes = nil)
    @remote_size ||= request_object_size

    # If the resource is empty there is nothing to read
    return nil if @remote_size.zero?

    maximum_avaialable = @remote_size - @pos
    n_bytes ||= maximum_avaialable # nil == read to the end of file
    return '' if n_bytes.zero?
    raise ArgumentError, "No negative reads(#{n_bytes})" if n_bytes < 0

    n_bytes = clamp(0, n_bytes, maximum_avaialable)

    read_n_bytes_from_remote(@pos, n_bytes).tap do |data|
      if data.bytesize != n_bytes
        raise "Remote read returned #{data.bytesize} bytes instead of #{n_bytes} as requested"
      end
      @pos = clamp(0, @pos + data.bytesize, @remote_size)
    end
  end

  # Returns the current pointer position within the IO
  #
  # @return [Fixnum]
  def tell
    @pos
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
    http.request(request).body
  end
  
  # Only used internally when reading the remote ZIP.
  #
  # @return [Fixnum] the byte size of the ranged request
  def request_object_size
    http = Net::HTTP.start(@uri.hostname, @uri.port)
    http.request_head(@uri)['Content-Length'].to_i
  end

  # Reads N bytes at offset from remote
  def read_n_bytes_from_remote(start_at, n_bytes)
    range = (start_at..(start_at + n_bytes - 1))
    request_range(range)
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