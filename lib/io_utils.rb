module FormatParser::IOUtils
  class InvalidRead < ArgumentError
  end

  class MalformedFile < ArgumentError
  end

  def safe_read(io, n)
    raise ArgumentError, 'Unbounded reads are not supported' if n.nil?
    buf = io.read(n)

    unless buf
      raise InvalidRead, "We wanted to read #{n} bytes from the IO, but the IO is at EOF"
    end
    if buf.bytesize != n
      raise InvalidRead, "We wanted to read #{n} bytes from the IO, but we got #{buf.bytesize} instead"
    end

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
    safe_read(@buf, 1).unpack('C').first
  end

  def read_int_16
    safe_read(@buf, 2).unpack('n').first
  end

  def read_int_32
    safe_read(@buf, 4).unpack('N').first
  end

  def read_little_endian_int_16
    safe_read(@buf, 2).unpack('v').first
  end

  def read_little_endian_int_32
    safe_read(@buf, 4).unpack('V').first
  end

  # 'n' is the number of bytes to read
  def read_string(n)
    safe_read(@buf, n)
  end

  ### TODO: Some kind of built-in offset for the read
end
