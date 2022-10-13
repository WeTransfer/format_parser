class FormatParser::DPXParser
  # A teeny-tiny rewording of depix (https://rubygems.org/gems/depix)
  class Binstr
    TO_LITTLE_ENDIAN = {
      'N' => 'V',
      'n' => 'v',
    }

    class Capture < Struct.new(:pattern, :bytes)
      include FormatParser::IOUtils
      def read_and_unpack(io)
        platform_byte_order_pattern = io.le? ? TO_LITTLE_ENDIAN.fetch(pattern, pattern) : pattern
        safe_read(io, bytes).unpack(platform_byte_order_pattern).first
      end
    end

    def self.fields
      @fields ||= []
      @fields
    end

    def self.char(field_name, length, **_kwargs)
      fields << [field_name, Capture.new('Z%d' % length, length)]
    end

    def self.u8(field_name, **_kwargs)
      fields << [field_name, Capture.new('c', 1)]
    end

    def self.u16(field_name, **_kwargs)
      fields << [field_name, Capture.new('n', 2)]
    end

    def self.u32(field_name, **_kwargs)
      fields << [field_name, Capture.new('N', 4)]
    end

    def self.r32(field_name, **_kwargs)
      fields << [field_name, Capture.new('e', 4)]
    end

    def self.blanking(field_name, length, **_kwargs)
      fields << [field_name, Capture.new('x%d' % length, length)]
    end

    def self.array(field_name, nested_struct_descriptor_or_symbol, n_items, **_kwargs)
      if nested_struct_descriptor_or_symbol.is_a?(Symbol)
        n_items.times do |i|
          public_send(nested_struct_descriptor_or_symbol, '%s_%d' % [field_name, i])
        end
      else
        n_items.times do |i|
          fields << ['%s_%d' % [field_name, i], nested_struct_descriptor_or_symbol]
        end
      end
    end

    def self.inner(field_name, nested_struct_descriptor, **_kwargs)
      fields << [field_name, nested_struct_descriptor]
    end

    def self.cleanup(v)
      case v
      when String
        v.scrub
      when Float
        v.nan? ? nil : v
      else
        v
      end
    end

    def self.read_and_unpack(io)
      fields.each_with_object({}) do |(field_name, capture), h|
        maybe_value = cleanup(capture.read_and_unpack(io))
        h[field_name] = maybe_value unless maybe_value.nil?
      end
    end
  end

  class FileInfo < Binstr
    char :magic, 4,       desc: 'Endianness (SDPX is big endian)', req: true
    u32  :image_offset,   desc: 'Offset to image data in bytes', req: true
    char :version, 8,     desc: 'Version of header format', req: true

    u32  :file_size,      desc: 'Total image size in bytes', req: true
    u32  :ditto_key,      desc: 'Whether the basic headers stay the same through the sequence (1 means they do)'
    u32  :generic_size,   desc: 'Generic header length'
    u32  :industry_size,  desc: 'Industry header length'
    u32  :user_size,      desc: 'User header length'

    char :filename, 100,  desc: 'Original filename'
    char :timestamp, 24,  desc: 'Creation timestamp'
    char :creator, 100,   desc: 'Creator application'
    char :project, 200,   desc: 'Project name'
    char :copyright, 200, desc: 'Copyright'

    u32  :encrypt_key,    desc: 'Encryption key'
    blanking :reserve, 104
  end

  class FilmInfo < Binstr
    char :id, 2,          desc: 'Film mfg. ID code (2 digits from film edge code)'
    char :type, 2,        desc: 'Film type (2 digits from film edge code)'
    char :offset, 2,      desc: 'Offset in perfs (2 digits from film edge code)'
    char :prefix, 6,      desc: 'Prefix (6 digits from film edge code'
    char :count, 4,       desc: 'Count (4 digits from film edge code)'
    char :format, 32,     desc: 'Format (e.g. Academy)'

    u32 :frame_position,  desc: 'Frame position in sequence'
    u32 :sequence_extent, desc: 'Sequence length'
    u32 :held_count,      desc: 'For how many frames the frame is held'

    r32 :frame_rate,      desc: 'Frame rate'
    r32 :shutter_angle,   desc: 'Shutter angle'

    char :frame_id, 32,   desc: 'Frame identification (keyframe)'
    char :slate, 100,     desc: 'Slate information'
    blanking :reserve, 56
  end

  class ImageElement < Binstr
    u32 :data_sign, desc: 'Data sign (0=unsigned, 1=signed). Core is unsigned', req: true

    u32 :low_data,      desc: 'Reference low data code value'
    r32 :low_quantity,  desc: 'Reference low quantity represented'
    u32 :high_data,     desc: 'Reference high data code value (1023 for 10bit per channel)'
    r32 :high_quantity, desc: 'Reference high quantity represented'

    u8 :descriptor,   desc: 'Descriptor for this image element (ie Video or Film), by enum', req: true
    u8 :transfer,     desc: 'Transfer function (ie Linear), by enum', req: true
    u8 :colorimetric, desc: 'Colorimetric (ie YcbCr), by enum', req: true
    u8 :bit_size,     desc: 'Bit size for element (ie 10)', req: true

    u16 :packing,     desc: 'Packing (0=Packed into 32-bit words, 1=Filled to 32-bit words))', req: true
    u16 :encoding,    desc: 'Encoding (0=None, 1=RLE)', req: true
    u32 :data_offset, desc: 'Offset to data for this image element', req: true
    u32 :end_of_line_padding, desc: 'End-of-line padding for this image element'
    u32 :end_of_image_padding, desc: 'End-of-line padding for this image element'
    char :description, 32
  end

  class OrientationInfo < Binstr
    u32 :x_offset
    u32 :y_offset

    r32 :x_center
    r32 :y_center

    u32 :x_size, desc: 'Original X size'
    u32 :y_size, desc: 'Original Y size'

    char :filename, 100, desc: 'Source image filename'
    char :timestamp, 24, desc: 'Source image/tape timestamp'
    char :device,    32, desc: 'Input device or tape'
    char :serial,    32, desc: 'Input device serial number'

    array :border, :u16, 4, desc: 'Border validity: XL, XR, YT, YB'
    u32 :horizontal_pixel_aspect, desc: 'Aspect (H)'
    u32 :vertical_pixel_aspect, desc: 'Aspect (V)'

    blanking :reserve, 28
  end

  class TelevisionInfo < Binstr
    u32 :time_code, desc: 'Timecode, formatted as HH:MM:SS:FF in the 4 higher bits of each 8bit group'
    u32 :user_bits, desc: 'Timecode UBITs'
    u8 :interlace,  desc: 'Interlace (0 = noninterlaced; 1 = 2:1 interlace'

    u8 :field_number, desc: 'Field number'
    u8 :video_signal, desc: 'Video signal (by enum)'
    u8 :padding,      desc: 'Zero (for byte alignment)'

    r32 :horizontal_sample_rate, desc: 'Horizontal sampling Hz'
    r32 :vertical_sample_rate,   desc: 'Vertical sampling Hz'
    r32 :frame_rate,             desc: 'Frame rate'
    r32 :time_offset,            desc: 'From sync pulse to first pixel'
    r32 :gamma,                  desc: 'Gamma'
    r32 :black_level,            desc: 'Black pedestal code value'
    r32 :black_gain,             desc: 'Black gain code value'
    r32 :break_point,            desc: 'Break point (?)'
    r32 :white_level,            desc: 'White level'
    r32 :integration_times,      desc: 'Integration times (S)'
    blanking :reserve, 4 # As long as a real
  end

  class UserInfo < Binstr
    char :id, 32, desc: 'Name of the user data tag'
    u32 :user_data_ptr
  end

  class ImageInfo < Binstr
    u16 :orientation,                       desc: 'To which orientation descriptor this relates',    req: true
    u16 :number_elements,                   desc: 'How many elements to scan', req: true

    u32 :pixels_per_line,                   desc: 'Pixels per horizontal line', req: true
    u32 :lines_per_element,                 desc: 'Line count', req: true

    array :image_elements, ImageElement, 8, desc: 'Image elements'

    blanking :reserve, 52

    # Only expose the elements present
    def image_elements # :nodoc:
      @image_elements[0...number_elements]
    end
  end

  # This is the main structure represinting headers of one DPX file
  class DPX < Binstr
    inner :file, FileInfo,   desc: 'File information', req: true
    inner :image, ImageInfo, desc: 'Image information', req: true
    inner :orientation, OrientationInfo, desc: 'Orientation', req: true
    inner :film, FilmInfo, desc: 'Film industry info', req: true
    inner :television, TelevisionInfo, desc: 'TV industry info', req: true
    blanking :user, 32 + 4, desc: 'User info', req: true

    def self.read_and_unpack(io)
      super.tap do |h|
        num_elems = h[:image][:number_elements]
        num_elems.upto(8) do |n|
          h[:image].delete("image_elements_#{n}")
        end
      end
    end
  end

  private_constant :Binstr, :FileInfo, :FilmInfo, :ImageElement, :OrientationInfo, :TelevisionInfo, :UserInfo, :ImageInfo
end
