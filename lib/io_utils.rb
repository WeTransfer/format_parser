module FormatParser::IOUtils
  class InvalidRead < ArgumentError
  end

  class MalformedFile < ArgumentError
  end

  def safe_read(io, n)
    raise ArgumentError, 'Unbounded reads are not supported' if n.nil?
    buf = io.read(n)

    raise InvalidRead, "We wanted to read #{n} bytes from the IO, but the IO is at EOF" unless buf
    raise InvalidRead, "We wanted to read #{n} bytes from the IO, but we got #{buf.bytesize} instead" if buf.bytesize != n

    buf
  end

  def safe_skip(io, n)
    raise ArgumentError, 'Unbounded skips are not supported' if n.nil?

    return if n == 0

    raise InvalidRead, 'Negative skips are not supported' if n < 0

    io.seek(io.pos + n)
    nil
  end

  def read_int_8
    read_bytes(1).unpack('C').first
  end

  def read_int_16
    read_bytes(2).unpack('n').first
  end

  def read_int_32
    read_bytes(4).unpack('N').first
  end

  def read_int_64
    read_bytes(8).unpack('Q>').first
  end

  def read_little_endian_int_16
    read_bytes(2).unpack('v').first
  end

  def read_little_endian_int_32
    read_bytes(4).unpack('V').first
  end

  def read_fixed_point_16
    read_bytes(2).unpack('C2')
  end

  def read_fixed_point_32
    read_bytes(4).unpack('n2')
  end

  def read_fixed_point_32_2_30
    n = read_int_32
    [n >> 30, n & 0x3fffffff]
  end

  def read_string(n)
    safe_read(@buf, n)
  end

  # 'n' is the number of bytes to read
  def read_bytes(n)
    safe_read(@buf, n)
  end

  def skip_bytes(n)
    safe_skip(@buf, n)
  end

  def skip_bytes_then(n)
    skip_bytes(n)
    yield
  end

  ### TODO: Some kind of built-in offset for the read
end
