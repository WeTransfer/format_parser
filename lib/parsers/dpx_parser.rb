require 'delegate'

class FormatParser::DPXParser
  include FormatParser::IOUtils
  require_relative 'dpx_parser/dpx_structs'
  BE_MAGIC = 'SDPX'
  LE_MAGIC = BE_MAGIC.reverse

  class ByteOrderHintIO < SimpleDelegator
    def initialize(io, is_little_endian)
      super(io)
      @little_endian = is_little_endian
    end

    def le?
      @little_endian
    end
  end

  private_constant :ByteOrderHintIO

  def likely_match?(filename)
    filename =~ /\.dpx$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    magic = safe_read(io, 4)
    return unless [BE_MAGIC, LE_MAGIC].include?(magic)

    io.seek(0)

    dpx_structure = DPX.read_and_unpack(ByteOrderHintIO.new(io, magic == LE_MAGIC))

    w = dpx_structure.fetch(:image).fetch(:pixels_per_line)
    h = dpx_structure.fetch(:image).fetch(:lines_per_element)

    display_w = w
    display_h = h

    pixel_aspect_w = dpx_structure.fetch(:orientation).fetch(:horizontal_pixel_aspect)
    pixel_aspect_h = dpx_structure.fetch(:orientation).fetch(:vertical_pixel_aspect)

    # Find display height and width based on aspect only if the file structure has pixel aspects
    if pixel_aspect_h != 0 && pixel_aspect_w != 0
      pixel_aspect = pixel_aspect_w / pixel_aspect_h.to_f

      image_aspect = w / h.to_f * pixel_aspect

      if image_aspect > 1
        display_h = (display_w / image_aspect).round
      else
        display_w = (display_h * image_aspect).round
      end
    end

    FormatParser::Image.new(
      format: :dpx,
      width_px: w,
      height_px: h,
      display_width_px: display_w,
      display_height_px: display_h,
      intrinsics: dpx_structure,
    )
  end

  FormatParser.register_parser new, natures: :image, formats: :dpx
end
