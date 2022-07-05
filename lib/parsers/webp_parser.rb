# WebP is an image format that provides superior lossless and lossy compression for images on the web, with support for
# transparency. It uses predictive coding to encode an image, predicting the values in a block of pixels based on the
# values of neighbouring blocks. A WebP file consists of VP8 or VP8L data, and a container based on RIFF. There is also
# an extended file format, VP8X, that optionally encodes various information such as the color profile, animation
# control data, transparency, and EXIF and/or XMP metadata.
#
# For more information, visit https://developers.google.com/speed/webp.
#
# TODO: Decide how to determine color mode (depends on variant, transformations, flags, etc.; maybe not worth it).

class FormatParser::WebpParser
  include FormatParser::EXIFParser
  include FormatParser::IOUtils

  WEBP_MIME_TYPE = 'image/webp'

  def likely_match?(filename)
    filename =~ /\.webp$/i
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)

    # All WebP files start with the following 20 bytes:
    #
    # Offset  | Description
    # -------------------------------------------------------------------------------------
    # 0...3   | "RIFF" (Since WebP is based on the RIFF file container format).
    # 4...7   | The size of the file in bytes - 8 bytes.
    # 8...11  | "WEBP" (To signify that this is a WebP file).
    # 12...15 | The VB8 variant in use ("VB8 ", "VP8L" or "VB8X")
    # 16...19 | The length of the VB8 data in bytes (i.e. The size of the file - 20 bytes).
    riff, webp, variant = safe_read(@buf, 20).unpack('A4x4A4A4')
    return unless riff == 'RIFF' && webp == 'WEBP'
    read_data(variant)
  end

  private

  def read_data(variant)
    case variant
    when 'VP8' # Lossy
      read_lossy_data
    when 'VP8L' # Lossless
      read_lossless_data
    when 'VP8X' # Extended
      read_extended_data
    else
      nil
    end
  end

  def read_lossy_data
    # Encoded as a single VP8 key frame - a 10-byte uncompressed chunk followed by 2+ partitions of compressed data.
    # The first 6 bytes of this chunk contains information that is mostly relevant when using VP8 as a video
    # compression format, and can be ignored.
    safe_skip(@buf, 6)

    # The subsequent 4 bytes contain the image width and height, respectively, as 16-bit unsigned little endian
    # integers.
    width, height = safe_read(@buf, 4).unpack('S<S<')
    create_image(width, height)
  end

  def read_lossless_data
    # There is a single byte signature, 0x2F, that we can disregard.
    safe_skip(@buf, 1)

    # The subsequent 4 bytes contain the image width and height, respectively, as 14-bit unsigned little endian
    # integers (minus one). The 4 remaining bits consist of a 1-bit flag indicating whether alpha is used, and a 3-bit
    # version that is always zero.
    dimensions = read_little_endian_int_32
    width = (dimensions & 0x3fff) + 1
    height = (dimensions >> 14 & 0x3fff) + 1
    has_transparency = (dimensions >> 28 & 0x1) == 1

    create_image(width, height, has_transparency: has_transparency)
  end

  def read_extended_data
    # After the common RIFF header bytes, the extended file format has a series of 1-bit flags to signify the presence
    # of optional information. These flags are as follows:
    #
    # |0|1|2|3|4|5|6|7|
    # +-+-+-+-+-+-+-+-+
    # |Rsv|I|L|E|X|A|R|
    #
    # Where:
    #   - Rsv & R = Reserved - Should be 0.
    #   - I = Set if file contains an ICC profile.
    #   - L = Set if file contains transparency information.
    #   - E = Set if file contains Exif metadata.
    #   - X = Set if file contains XMP metadata.
    #   - A = Set if file is an animated image.
    flags = read_int_8
    has_transparency = flags & 0x10 != 0
    has_exif_metadata = flags & 0x08 != 0
    has_xmp_metadata = flags & 0x04 != 0
    has_multiple_frames = flags & 0x02 != 0

    # The flags are followed by three reserved bytes of zeros, and then by the width and height, respectively - each
    # occupying three bytes and each one less than the actual canvas measurements.
    safe_skip(@buf, 3)
    dimensions = safe_read(@buf, 6).unpack('VS')
    width = (dimensions[0] & 0xffffff) + 1
    height = (dimensions[0] >> 24 | dimensions[1] << 8 & 0xffffff) + 1

    image = create_image(width, height, has_multiple_frames: has_multiple_frames, has_transparency: has_transparency)
    augment_image(image) if has_exif_metadata || has_xmp_metadata || has_multiple_frames
    image
  end

  def create_image(width, height, has_multiple_frames: false, has_transparency: false)
    FormatParser::Image.new(
      content_type: WEBP_MIME_TYPE,
      format: :webp,
      has_multiple_frames: has_multiple_frames,
      has_transparency: has_transparency,
      height_px: height,
      width_px: width
    )
  end

  def augment_image(image)
    # We're going to scan the file looking for the EXIF, XMP and/or ANMF chunks.
    exif = nil
    xmp = nil
    num_frames = 0
    loop do
      fourcc, chunk_size = safe_read(@buf, 8).unpack('A4V')
      safe_skip(@buf, 1) if chunk_size.odd? # Padding byte of 0 added if chunk size is odd.
      case fourcc
      when 'EXIF'
        exif ||= exif_from_tiff_io(StringIO.new(safe_read(@buf, chunk_size)))
      when 'XMP'
        safe_skip(@buf, chunk_size)
      when 'ANMF'
        num_frames += 1 if image.has_multiple_frames
        safe_skip(@buf, chunk_size)
      else
        safe_skip(@buf, chunk_size)
      end
    end
  rescue FormatParser::IOUtils::InvalidRead
    if exif || xmp
      image.intrinsics = {}
      if exif
        image.height_px, image.width_px = image.width_px, image.height_px if exif.rotated?
        image.intrinsics[:exif] = exif
        image.orientation = exif.orientation_sym
      end
      image.intrinsics[:xmp] = xmp if xmp
    end
    image.num_animation_or_video_frames = num_frames if num_frames > 0
  end

  FormatParser.register_parser new, natures: [:image], formats: [:webp]
end
