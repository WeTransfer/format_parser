# Based on https://en.wikipedia.org/wiki/BMP_file_format

class FormatParser::BMPParser
  include FormatParser::IOUtils

  VALID_BMP = 'BM'
  PERMISSIBLE_PIXEL_ARRAY_LOCATIONS = 40..512

  def self.likely_match?(filename)
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

    _header_size, width, height, _planes, _bits_per_pixel,
    _compression_method, _image_size, horizontal_res,
    vertical_res, _n_colors, _i_colors = dib_header.unpack('Vl<2v2V2l<2V2')

    # There are cases where the height might by negative indicating the data
    # is ordered from top to bottom instead of bottom to top
    # http://www.dragonwins.com/domains/getteched/bmp/bmpfileformat.htm#The%20Image%20Header
    data_order = height < 0 ? :inverse : :normal

    FormatParser::Image.new(
      format: :bmp,
      width_px: width,
      height_px: height.abs,
      color_mode: :rgb,
      intrinsics: {
        vertical_resolution: vertical_res,
        horizontal_resolution: horizontal_res,
        data_order: data_order
      }
    )
  end

  FormatParser.register_parser self, natures: :image, formats: :bmp
end
