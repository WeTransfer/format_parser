class FormatParser::TIFFParser
  LITTLE_ENDIAN_TIFF_HEADER_BYTES = [0x49, 0x49, 0x2A, 0x0]
  BIG_ENDIAN_TIFF_HEADER_BYTES = [0x4D, 0x4D, 0x0, 0x2A]
  WIDTH_TAG  = 0x100
  HEIGHT_TAG = 0x101

  include FormatParser::IOUtils


  def information_from_io(io)
    io.seek(0)
    magic_bytes = safe_read(io, 4).unpack("C4")
    endianness = scan_tiff_endianness(magic_bytes)
    return unless endianness
    w, h = read_tiff_by_endianness(io, endianness)
    return FormatParser::FileInformation.new(width_px: w, height_px: h)
  end

  def scan_tiff_endianness(magic_bytes)
    if magic_bytes == LITTLE_ENDIAN_TIFF_HEADER_BYTES
      endianness = "v"
    elsif magic_bytes == BIG_ENDIAN_TIFF_HEADER_BYTES
      endianness = "n"
    else
      endianness = nil
    end
  end

  def scan_ifd(cache, offset, endianness)
    entry_count = safe_read(cache, 4).unpack(endianness)[0]
    entry_count.times do |i|
      cache.seek(offset + 2 + (12 * i))
      tag = safe_read(cache, 4).unpack(endianness)[0]
      if tag == WIDTH_TAG
        @width = safe_read(cache, 4).unpack(endianness.upcase)[0]
      elsif tag == HEIGHT_TAG
        @height = safe_read(cache, 4).unpack(endianness.upcase)[0]
      end
    end

  end


  def read_tiff_by_endianness(io, endianness)
    offset = safe_read(io, 4).unpack(endianness.upcase)[0]
    cache = Care::IOWrapper.new(io)
    cache.seek(offset)
    scan_ifd(cache, offset, endianness)
    [@width, @height]
  end

  def raise_tiff_scan_error
    raise TIFFScanError
  end

end
