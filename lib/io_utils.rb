module FormatParser::IOUtils
  INTEGER_DIRECTIVES = {
    1 => 'C',
    2 => 'S',
    4 => 'L',
    8 => 'Q'
  }

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

  # Read an integer.
  # @param [Integer] n Number of bytes. Defaults to 4 (32-bit).
  # @param [Boolean] signed Signed if true, Unsigned if false. Defaults to false. (unsigned)
  # @param [Boolean] big_endian Big-endian if true, little-endian if false. Defaults to true (big-endian).
  def read_int(n: 4, signed: false, big_endian: true)
    directive = INTEGER_DIRECTIVES[n]
    directive.downcase! if signed
    directive += (big_endian ? ">" : "<") if n > 1
    read_bytes(n).unpack(directive).first
  end

  def read_fixed_point(fractional_digits: 16, **kwargs)
    read_int(**kwargs) / 2.0**fractional_digits
  end

  # 'n' is the number of bytes to read
  def read_bytes(n)
    safe_read(@buf, n)
  end

  alias_method :read_string, :read_bytes

  def skip_bytes(n)
    safe_skip(@buf, n)
    yield if block_given?
  end

  ### TODO: Some kind of built-in offset for the read
end
