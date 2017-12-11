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
    return FormatParser::FileInformation.new(width_px: w, height_px: h)
    
    # and actually onwards for this:
    # http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp
  end
end
