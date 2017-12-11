class FormatParser::GIFParser
  HEADERS = ['GIF87a', 'GIF89a'].map(&:b)
  NETSCAPE_AND_AUTHENTICATION_CODE = 'NETSCAPE2.0'

  include FormatParser::IOUtils

  def information_from_io(io)
    io.seek(0)
    header = safe_read(io, 6)
    return unless HEADERS.include?(header)

    w, h = safe_read(io, 4).unpack('vv')
    gct_byte, bgcolor_index, pixel_aspect_ratio = safe_read(io, 5).unpack('Cvv')

    # and actually onwards for this:
    # http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp
    
    # Determine how big our color table is
    has_gct = gct_byte[0] == 1
    bytes_per_color = gct_byte >> 6
    unpacked_radix = gct_byte & 0b00000111
    num_colors = 2**(unpacked_radix + 1)
    gct_table_size = num_colors*bytes_per_color

    # If we have the global color table - skip over it
    if has_gct
      safe_read(io, gct_table_size)
    end

    # Now it gets interesting - potentially we are at the place where an
    # application extension for the NETSCAPE2.0 block will occur
    raise safe_read(io, 64).inspect

    return FormatParser::FileInformation.new(width_px: w, height_px: h)
  end
end
