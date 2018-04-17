# Based on https://en.wikipedia.org/wiki/BMP_file_format

class FormatParser::BMPParser
  include FormatParser::IOUtils

  VALID_BMP = 'BM'
  PIXEL_ARRAY_OFFSET = 54

  def call(io)
    io = FormatParser::IOConstraint.new(io)

    magic_number, _file_size, _reserved1, _reserved2, dib_header_location = safe_read(io, 14).unpack('A2Vv2V')
    return unless VALID_BMP == magic_number
    return unless dib_header_location == PIXEL_ARRAY_OFFSET

    dib_header = safe_read(io, 40)

    _header_size, width, height, _planes, _bits_per_pixel,
    _compression_method, _image_size, horizontal_res,
    vertical_res, _n_colors, _i_colors = dib_header.unpack('Vl<2v2V2l<2V2')

    FormatParser::Image.new(
      format: :bmp,
      width_px: width,
      height_px: height,
      color_mode: :rgb,
      intrinsics: {
        vertical_resolution: vertical_res,
        horizontal_resolution: horizontal_res
      }
    )
  end

  FormatParser.register_parser self, natures: :image, formats: :bmp
end
