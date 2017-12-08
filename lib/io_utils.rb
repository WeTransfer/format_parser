module FormatParser::IOUtils
  def safe_read(io, n)
    buf = io.read(n)
    if !buf
      raise "We wanted to read #{n} bytes from the IO, but the IO is at EOF"
    end
    if buf.bytesize != n
      raise "We wanted to read #{n} bytes from the IO, but we got #{buf.bytesize} instead"
    end
    buf
  end
end
