class FormatParser::GIFParser
  include FormatParser::IOUtils

  HEADERS = ['GIF87a', 'GIF89a'].map(&:b)
  NETSCAPE_AND_AUTHENTICATION_CODE = 'NETSCAPE2.0'

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    header = safe_read(io, 6)
    return unless HEADERS.include?(header)

    w, h = safe_read(io, 4).unpack('vv')
    gct_byte, _bgcolor_index, _pixel_aspect_ratio = safe_read(io, 5).unpack('Cvv')

    # and actually onwards for this:
    # http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp

    # Determine how big our color table is
    has_gct = gct_byte[0] == 1
    bytes_per_color = gct_byte >> 6
    unpacked_radix = gct_byte & 0b00000111
    num_colors = 2**(unpacked_radix + 1)
    gct_table_size = num_colors * bytes_per_color

    # If we have the global color table - skip over it
    safe_read(io, gct_table_size) if has_gct

    # Now it gets interesting - we are at the place where an
    # application extension for the NETSCAPE2.0 block will occur.
    # If it does, it most likely means the application that wrote the
    # GIF needed looping, and if it did, it means that the GIF is
    # very, very likely to be animated. To read the actual animation
    # we need to skip over actual image data frames, which, in case
    # of our paged reads, will incur
    potentially_netscape_app_header = safe_read(io, 64)
    is_animated = potentially_netscape_app_header.include?(NETSCAPE_AND_AUTHENTICATION_CODE)

    FormatParser::Image.new(
      format: :gif,
      width_px: w,
      height_px: h,
      has_multiple_frames: is_animated,
      color_mode: :indexed,
    )
  end

  FormatParser.register_parser self, natures: :image, formats: :gif
end
