module FormatParser::IOUtils
  def safe_read(io, n)
    if n.nil?
      raise ArgumentError, "Unbounded reads are not supported"
    end
    buf = io.read(n)
    
    if !buf
      raise "We wanted to read #{n} bytes from the IO, but the IO is at EOF"
    end
    if buf.bytesize != n
      raise "We wanted to read #{n} bytes from the IO, but we got #{buf.bytesize} instead"
    end
    
    buf
  end

  def safe_skip(io, n)
    if n.nil?
      raise ArgumentError, "Unbounded skips are not supported"
    end

    return if n == 0

    if n < 0
      raise ArgumentError, "Negative skips are not supported"
    end

    if io.respond_to?(:pos)
      io.seek(io.pos + n)
    else
      safe_read(io, n)
    end
    nil
  end

  ### TODO: Some kind of safe_seek method, plus an offset for the read
end
