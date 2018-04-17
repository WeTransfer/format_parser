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

  ### TODO: Some kind of built-in offset for the read
end
