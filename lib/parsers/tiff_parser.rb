class FormatParser::TIFFParser
  include FormatParser::IOUtils
  include FormatParser::DSL

  LITTLE_ENDIAN_TIFF_HEADER_BYTES = [0x49, 0x49, 0x2A, 0x0]
  BIG_ENDIAN_TIFF_HEADER_BYTES = [0x4D, 0x4D, 0x0, 0x2A]
  WIDTH_TAG  = 0x100
  HEIGHT_TAG = 0x101

  natures :image
  formats :tif

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    magic_bytes = safe_read(io, 4).unpack('C4')
    endianness = scan_tiff_endianness(magic_bytes)
    return unless endianness
    w, h = read_tiff_by_endianness(io, endianness)
    scanner = FormatParser::EXIFParser.new(:tiff, io)
    scanner.scan_image_exif
    FormatParser::Image.new(
      format: :tif,
      width_px: w,
      height_px: h,
      # might be nil if EXIF metadata wasn't found
      orientation: scanner.orientation
    )
  end

  # TIFFs can be either big or little endian, so we check here
  # and set our unpack method argument to suit.
  def scan_tiff_endianness(magic_bytes)
    if magic_bytes == LITTLE_ENDIAN_TIFF_HEADER_BYTES
      'v'
    elsif magic_bytes == BIG_ENDIAN_TIFF_HEADER_BYTES
      'n'
    end
  end

  # The TIFF format stores metadata in a flexible set of information fields
  # called tags, which are stored in a header referred to as the IFD or
  # Image File Directory. It is not necessarily in the same place in every image,
  # so we need to do some work to scan through it and find the tags we need.
  # For more information the TIFF wikipedia page is a reasonable place to start:
  # https://en.wikipedia.org/wiki/TIFF
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
    io.seek(offset)
    scan_ifd(io, offset, endianness)
    [@width, @height]
  end

  FormatParser.register_parser_constructor self
end
