# HEIF stands for High-Efficiency Image File format, which is basically a container that is capable of storing an image, or a sequence of images in a single file.
# There are a number of variants of HEIF, which can be used to store images, sequences of images, or videos using different codecs.
# The variant that Apple uses to store images and sequences of images in its iOS and macOS operating systems is High Efficiency Image Coding (HEIC), which uses HEVC / H.265 for content compression.
class FormatParser::HEIFParser
  include FormatParser::IOUtils

  HEIF_MARKER = [0x68, 0x65, 0x69, 0x63].pack('C4') # heif marker
  FILE_TYPE_BOX_MARKER = [0x66, 0x74, 0x79, 0x70].pack('C4') # ftyp marker
  META_BOX_MARKER = [0x6D, 0x65, 0x74, 0x61].pack('C4') # meta marker
  MIF1_MARKER = [0x6D, 0x69, 0x66, 0x31].pack('C4') # mif1 marker
  MSF1_MARKER = [0x6D, 0x73, 0x66, 0x31].pack('C4') # msf1 marker
  MEANINGLESS_BYTE = [0x00, 0x00, 0x00, 0x00].pack('C4')
  HANDLER_MARKER = [0x68, 0x64, 0x6C, 0x72].pack('C4') # hdlr marker
  ITEM_PROPERTIES_BOX = [0x69, 0x70, 0x72, 0x70].pack('C4') # iprp marker
  ITEM_PROPERTIES_CONTAINER_BOX = [0x69, 0x70, 0x63, 0x6F].pack('C4') # ipco marker
  IMAGE_SPATIAL_EXTENTS_BOX = [0x69, 0x73, 0x70, 0x65].pack('C4') # ispe marker
  PIXEL_ASPECT_RATIO_BOX = [0x70, 0x61, 0x73, 0x70].pack('C4') # pasp marker
  ITEM_INFO_BOX = [0x69, 0x69, 0x6E, 0x66].pack('C4') # iinf marker
  ITEM_INFO_ENTRY = [0x69, 0x6E, 0x66, 0x65].pack('C4') # infe marker
  MIME_MARKER = [0x6D, 0x69, 0x6D, 0x65].pack('C4') # mime marker
  COLOUR_INFO_BOX = [0x63, 0x6F, 0x6C, 0x72].pack('C4') # colr marker
  PIXEL_INFO_BOX = [0x70, 0x69, 0x78, 0x69].pack('C4') # pixi marker
  RELATIVE_LOCATION_BOX = [0x72, 0x6C, 0x6F, 0x63].pack('C4') # rloc marker
  CLEAN_APERTURE_BOX = [0x63, 0x6C, 0x61, 0x70].pack('C4') # clap marker
  PRIMARY_ITEM_BOX = [0x70, 0x69, 0x74, 0x6D].pack('C4') # pitm marker
  ITEM_PROPERTIES_ASSOCIATION_BOX = [0x69, 0x70, 0x6D, 0x61].pack('C4') # ipma marker
  IMAGE_ROTATION_BOX = [0x69, 0x72, 0x6F, 0x74].pack('C4') # irot marker
  HEADER_LENGTH = 8 # every box header has a length of 8 bytes
  HEIC_MIME_POSSIBLE_TYPES = {
    'heic' => :heic,
    'heix' => :heix,
    'heim' => :heim,
    'heis' => :heis
  }
  HEIC_MIME_TYPE = 'image/heic'
  HEIF_MIME_TYPE = 'image/heif'
  # HEIC_SEQUENCE_MIME_TYPE = 'image/heic-sequence' # TODO: to be used when adding image-sequence parsing
  # HEIF_SEQUENCE_MIME_TYPE = 'image/heif-sequence'

  def self.call(io)
    new.call(io)
  end

  def call(io)
    @buf                = FormatParser::IOConstraint.new(io)
    @format             = nil
    @@major_brand       = nil
    @width              = nil
    @height             = nil
    @exif_data_frames   = []
    @compatible_brands  = nil
    @metadata_start_pos = 0
    @metadata_end_pos   = 0
    @handler_type       = nil
    @sub_items          = nil
    @pixel_aspect_ratio = nil
    @colour_info        = nil
    @pixel_info         = nil
    @horizontal_offset  = nil
    @vertical_offset    = nil
    @clean_aperture     = nil
    @primary_item_id    = 0
    @item_props         = {}
    @rotation           = 0
    @item_props_idxs    = []
    @content_type       = nil
    scan
  end

  def scan
    # All HEIC files must be conform to ISO/IEC 23008-12:2017
    # Moreover, all HEIC files are conform to ISO/IEC 14496-12:2015 and should be conform to the Clause 4 of such spec.
    # Files are formed as a series of objects, called boxes. All data is contained in such boxes.
    # All boxes start with a header which defines both size and type.
    # The size is the entire size of the box, including the size and type header, fields, and all contained boxes.
    # The fields in the objects are stored with the most significant byte first, commonly known as network byte order or big-endian format.
    # A HEIC file must contain a File Type Box (ftyp).
    # A file conforms to all the requirements of the brands listed in the compatible_brands.
    scan_file_type_box

    # file may be identified by MIME type of Annex C of ISO/IEC 23008-12 if 'mif1' is the major brand or Annex D if 'msf1' is the major brand.
    # the MIME indicates the nature and format of our assortment of bytes
    # note particularly that the brand 'mif1' doesn't mandate a MovieBox ("moov").
    # One or more brands must be included in the list of compatible brands
    return if @compatible_brands.nil?
    if @compatible_brands&.include?(MIF1_MARKER)
      scan_meta_level_box
      if @major_brand == MIF1_MARKER
        @content_type = HEIF_MIME_TYPE
        @format = :heif
      elsif (@compatible_brands & HEIC_MIME_POSSIBLE_TYPES.keys).length > 0
        @format = :heic
        @content_type = HEIC_MIME_TYPE
      end
    end
    if @compatible_brands&.include?(MSF1_MARKER)
      # TODO
    end

    result = FormatParser::Image.new(
      format: @format,
      width_px: @width,
      height_px: @height,
      intrinsics: {
        'compatible_brands': @compatible_brands,
        'handler_type': @handler_type,
        # 'sub_items': @sub_items, # enable this if you want to output all the sub-items in the image
        'pixel_aspect_ratio': @pixel_aspect_ratio,
        'colour_info': @colour_info,
        'pixel_info': @pixel_info,
        'horizontal_offset': @horizontal_offset,
        'vertical_offset': @vertical_offset,
        'clean_aperture': @clean_aperture,
        'rotation': @rotation
      },
      content_type: @content_type
    )

    result
  end

  def scan_file_type_box
    file_type_box_length = read_int_32
    return unless read_string(4) == FILE_TYPE_BOX_MARKER
    @major_brand = read_string(4)
    return unless @major_brand == HEIF_MARKER || MIF1_MARKER
    read_string(4) # minor_brand

    # Subtracting from the total length of the box specified in the header the size header itself (8 bytes = header length and length of ftyp)
    # and the length of the major and minor brand, we obtain the compatible brands
    data_left_length = file_type_box_length - HEADER_LENGTH - HEIF_MARKER.length - 4

    @compatible_brands = []
    (data_left_length / 4).times do
      @compatible_brands << read_string(4)
    end
  end

  def scan_meta_level_box
    metadata_length = read_int_32
    return unless read_string(4) == META_BOX_MARKER
    @metadata_start_pos = @buf.pos
    @metadata_end_pos = @buf.pos + metadata_length - HEADER_LENGTH # the real data is always without the 8 initial bytes of the handler
    read_nil_version_and_flag

    # we are looking for box/containers right beneath the Meta box
    # we start with the HDLR (Handler) box..
    handler_length = read_int_32
    return unless read_string(4) == HANDLER_MARKER
    handler_length -= HEADER_LENGTH # subtract the header as usual (will not be mentioned anymore from now on)
    handler_start = @buf.pos
    # the handler type declares the type of metadata and thus the process by which the media-data in the track is presented
    # it also indicates the structure or format of the ‘meta’ box contents
    read_nil_version_and_flag
    read_string(4) # pre_defined bytes, always 4 null bytes in the hdlr box
    @handler_type = read_string(4)
    @buf.seek(handler_start + handler_length) # the remaining part is reserved

    # ..continue looking for the IINF box and especially for the IPRP box, containing info about the image itself
    next_box_length = read_int_32
    next_box = read_string(4)
    next_box_start_pos = @buf.pos
    while @buf.pos < @metadata_end_pos # we iterate over all next incoming boxed but without going outside the meta-box
      case next_box
      when PRIMARY_ITEM_BOX
        read_primary_item_box
      when ITEM_INFO_BOX
        read_item_info_box
      when ITEM_PROPERTIES_BOX
        read_item_properties_box
        fill_primary_values
      when next_box == ''
        break
      end
      next_box_length, next_box, next_box_start_pos = get_next_box(next_box_start_pos, next_box_length, @metadata_end_pos)
    end
  end

  def read_item_info_box
    version = read_int_8
    safe_skip(@buf, 3) # 0 flags
    entry_count = if version == 0
      read_int_16
    else
      read_int_32
    end
    @sub_items = []
    entry_count.times {
      item_info_entry_length = read_int_32
      return unless read_string(4) == ITEM_INFO_ENTRY
      item_info_end_pos = @buf.pos + item_info_entry_length - HEADER_LENGTH
      version = read_int_8
      safe_skip(@buf, 3) # 0 flags
      case version
      when 2
        item_id = read_int_16
      when 3
        item_id = read_int_32
      else
        return # wrong version according to standards, hence return
      end
      safe_skip(@buf, 2) # not interested in the item_protection_index
      item_type = read_string(4)
      content_encoding = ''
      if item_type == MIME_MARKER
        content_encoding = read_string(item_info_end_pos - @buf.pos).delete!("\0") # remove the null-termination part for output visualization reason
      end
      @sub_items << {'item_id': item_id, 'item_type': item_type, 'content_encoding': content_encoding}
      @buf.seek(item_info_end_pos) # we are not interested in anything else, go directly to the end of this 'infe' box
    }
  end

  def read_nil_version_and_flag
    safe_skip(@buf, 1) # version, always 0 in this current box
    safe_skip(@buf, 3) # flags, always 0 in this current box
  end

  def read_primary_item_box
    version = read_int_8
    safe_read(@buf, 3) # flags, always 0 in this current box
    @primary_item_id = if version == 0
      read_int_16
    else
      read_int_32
    end
  end

  # the ITEM_PROPERTIES_CONTAINER_BOX contains an implicitely 1-based index list of item properties.
  # While parsing such box we are storing the properties with its own index.
  # Reason behind is that the primary_item will be associated to some of these properties through the same index
  # and in order to output relevant data from the format_parser we need all the properties associated to the primary_item.
  # Hence the need of the association between an item and its properties, found in the ITEM_PROPERTIES_ASSOCIATION_BOX
  def read_item_properties_box
    ipco_length = read_int_32
    return unless read_string(4) == ITEM_PROPERTIES_CONTAINER_BOX
    read_item_properties_container_box(ipco_length)
    read_int_32 # ipma_length
    return unless read_string(4) == ITEM_PROPERTIES_ASSOCIATION_BOX
    read_item_properties_association_box
  end

  def read_item_properties_container_box(box_length)
    end_of_ipco_box = @buf.pos + box_length - HEADER_LENGTH
    item_prop_length = read_int_32
    item_prop_name = read_string(4)
    item_prop_start_pos = @buf.pos
    item_prop_index = 1
    while @buf.pos < end_of_ipco_box
      case item_prop_name
      when IMAGE_SPATIAL_EXTENTS_BOX
        read_nil_version_and_flag
        width = read_int_32
        height = read_int_32
        @item_props[item_prop_index] = {
          'type': IMAGE_SPATIAL_EXTENTS_BOX,
          'width': width,
          'height': height
        }
      when PIXEL_ASPECT_RATIO_BOX
        h_spacing = read_int_32
        v_spacing = read_int_32
        pixel_aspect_ratio = "#{h_spacing}/#{v_spacing}"
        @item_props[item_prop_index] = {
          'type': PIXEL_ASPECT_RATIO_BOX,
          'pixel_aspect_ratio': pixel_aspect_ratio
        }
      when COLOUR_INFO_BOX
        colour_info = {
          'colour_primaries': read_int_16,
          'transfer_characteristics': read_int_16,
          'matrix_coefficients': read_int_16
        }
        @item_props[item_prop_index] = {
          'type': COLOUR_INFO_BOX,
          'colour_info': colour_info
        }
      when PIXEL_INFO_BOX
        pixel_info = []
        read_nil_version_and_flag
        num_channels = read_int_8
        channel = 1
        while channel <= num_channels
          channel += 1
          pixel_info << {
            "bits_in_channel_#{channel}": read_int_8
          }
        end
        @item_props[item_prop_index] = {
          'type': PIXEL_INFO_BOX,
          'pixel_info': pixel_info
        }
      when RELATIVE_LOCATION_BOX
        read_nil_version_and_flag
        horizontal_offset = read_int_32
        vertical_offset = read_int_32
        @item_props[item_prop_index] = {
          'type': RELATIVE_LOCATION_BOX,
          'horizontal_offset': horizontal_offset,
          'vertical_offset': vertical_offset
        }
      when CLEAN_APERTURE_BOX
        clean_aperture = []
        clean_aperture << {
          'clean_aperture_width_n': read_int_32,
          'clean_aperture_width_d': read_int_32,
          'clean_aperture_height_n': read_int_32,
          'clean_aperture_height_d': read_int_32,
          'horiz_off_n': read_int_32,
          'horiz_off_d': read_int_32,
          'vert_off_n': read_int_32,
          'vert_off_d': read_int_32
        }
        @item_props[item_prop_index] = {
          'type': CLEAN_APERTURE_BOX,
          'clean_aperture': clean_aperture
        }
      when IMAGE_ROTATION_BOX
        read_nil_version_and_flag
        binary = convert_byte_to_binary(read_int_8)
        # we need only the last 2 bits to retrieve the angle multiplier. angle multiplier * 90 specifies the angle
        rotation = binary.slice(6, 2).join.to_i(2) * 90
        @item_props[item_prop_index] = {
          'type': IMAGE_ROTATION_BOX,
          'rotation': rotation
        }
      end
      item_prop_length, item_prop_name, item_prop_start_pos = get_next_box(item_prop_start_pos, item_prop_length, end_of_ipco_box)
      item_prop_index += 1
    end
  end

  def read_item_properties_association_box
    version = read_int_8
    safe_read(@buf, 2) # we skip the first 2 bytes of the flags (total of 3 bytes) cause we care only about the least significant bit
    flags = read_int_8
    entry_count = read_int_32
    item_id = 0
    entry_count.times do
      item_id = if version == 0
        read_int_16
      else
        read_int_32
      end

      association_count = read_int_8
      association_count.times do
        # we need to retrieve the "essential" bit wich is just the first bit in the next byte
        binary = convert_byte_to_binary(read_int_8)
        # essential_bit = binary[0] # uncomment if needed
        binary.concat(convert_byte_to_binary(read_int_8)) if (flags & 1) == 1 # if flag is 1 we need the next 15 bits instead of only the next 7 bits
        # we need to nullify the 1st bit since that one was the essential bit and doesn't count now to calculate the property index
        binary[0] = 0
        item_property_index = binary.join.to_i(2)
        # we are interested only in the primary item properties
        @item_props_idxs << item_property_index if item_id == @primary_item_id
      end

      # we are interested only in the primary item
      if item_id != @primary_item_id
        next
      else
        return
      end
    end
  end

  def fill_primary_values
    @item_props_idxs.each { |x|
      next if @item_props[x].nil?
      prop = @item_props[x]
      case prop[:type]
      when IMAGE_SPATIAL_EXTENTS_BOX
        @width = prop[:width]
        @height = prop[:height]
      when PIXEL_ASPECT_RATIO_BOX
        @pixel_aspect_ratio = prop[:pixel_aspect_ratio]
      when COLOUR_INFO_BOX
        @colour_info = prop[:colour_info]
      when PIXEL_INFO_BOX
        @pixel_info = prop[:pixel_info]
      when RELATIVE_LOCATION_BOX
        @horizontal_offset = prop[:horizontal_offset]
        @vertical_offset = prop[:vertical_offset]
      when CLEAN_APERTURE_BOX
        @clean_aperture = prop[:clean_aperture]
      when IMAGE_ROTATION_BOX
        @rotation = prop[:rotation]
      end
    }
  end

  def next_meaningful_meta_byte
    while @buf.pos < @metadata_end_pos
      next_byte = read_string(4)
      return next_byte if meaningful?(next_byte)
    end
  end

  def get_next_box(box_start_pos, box_length, end_pos_upper_box)
    skip_pos = box_start_pos + box_length - HEADER_LENGTH
    @buf.seek(skip_pos)
    return if skip_pos >= end_pos_upper_box
    next_box_length = read_int_32
    next_box_name = read_string(4)
    [next_box_length, next_box_name, @buf.pos]
  end

  def meaningful?(byte)
    byte != MEANINGLESS_BYTE
  end

  def convert_byte_to_binary(integer)
    binary = []
    while integer > 0
      binary << integer % 2
      integer /= 2
    end
    binary_value = binary.reverse
    (8 - binary_value.length).times do
      binary_value.prepend('0')
    end
    binary_value
  end

  def likely_match?(filename)
    filename =~ /\.hei[cf]$/i
  end

  FormatParser.register_parser(new, natures: :image, formats: [:heif, :heic], priority: 2)
end
