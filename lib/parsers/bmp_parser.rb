# Based on https://en.wikipedia.org/wiki/BMP_file_format

class FormatParser::BMPParser
  include FormatParser::IOUtils

  VALID_BMP = 'BM'
  PERMISSIBLE_PIXEL_ARRAY_LOCATIONS = 26..512
  BMP_MIME_TYPE = 'image/bmp'

  def likely_match?(filename)
    filename =~ /\.bmp$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    magic_number, _file_size, _reserved1, _reserved2, pix_array_location = safe_read(io, 14).unpack('A2Vv2V')
    return unless VALID_BMP == magic_number

    # The number that gets unpacked can be fairly large, but in practice this offset cannot be too big -
    # the DIB image header won't be that big anyway/
    return unless PERMISSIBLE_PIXEL_ARRAY_LOCATIONS.cover?(pix_array_location)

    dib_header = safe_read(io, 40)
    header_size = dib_header.unpack('V')[0]
    case header_size
    when 12 # OS21XBITMAPHEADER
      parse_bitmap_core_header(dib_header)
    else # More modern implementations
      parse_modern_header(dib_header)
    end
  end

  def parse_bitmap_core_header(dib_header)
    _header_size, width, height, _num_color_planes, bit_depth = dib_header.unpack('VSSSS')

    # In core bitmap format an unsigned int is used for dimensions,
    # no inverse scan order is possible
    data_order = :normal

    FormatParser::Image.new(
      format: :bmp,
      width_px: width,
      height_px: height,
      color_mode: :rgb,
      content_type: BMP_MIME_TYPE,
      intrinsics: {
        data_order: data_order,
        bits_per_pixel: bit_depth
      }
    )
  end

  def parse_modern_header(dib_header)
    _header_size, width, height, _planes, bits_per_pixel,
    _compression_method, _image_size, horizontal_res,
    vertical_res, _n_colors, _i_colors = dib_header.unpack('Vl<2v2V2l<2V2')

    # There are cases where the height might by negative indicating the data
    # is ordered from top to bottom instead of bottom to top
    data_order = height < 0 ? :inverse : :normal

    FormatParser::Image.new(
      format: :bmp,
      width_px: width,
      height_px: height.abs,
      color_mode: :rgb,
      content_type: BMP_MIME_TYPE,
      intrinsics: {
        vertical_resolution: vertical_res,
        horizontal_resolution: horizontal_res,
        data_order: data_order,
        bits_per_pixel: bits_per_pixel,
      }
    )
  end

  FormatParser.register_parser new, natures: :image, formats: :bmp
end
