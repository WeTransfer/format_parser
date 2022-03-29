class FormatParser::HEIFParser
  include FormatParser::IOUtils

  MAJOR_BRAND_MARKER = [0x68, 0x65, 0x69, 0x63].pack('C4') # heif marker
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
  # IMAGE_ROTATION_BOX = [0x69, 0x72, 0x6F, 0x74].pack('C4') # irot marker
  HEADER_LENGTH = 8 # every box header has a length of 8 bytes

  def self.call(io)
    new.call(io)
  end

  def call(io)
    @buf = FormatParser::IOConstraint.new(io)
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
    scan
  end

  def scan
    # All HEIC files must be conform to ISO/IEC 23008-12:2017
    # Moreover, all HEIC files are conform to ISO/IEC 14496-12:2015 and should be conform to the Clause 4 of such spec.
    # Files are formed as a series of objects, called boxes. All data is contained in boxes.
    # Boxes start with a header which gives both size and type.
    # The size is the entire size of the box, including the size and type header, fields, and all contained boxes.
    # The fields in the objects are stored with the most significant byte first, commonly known as network byte order or big-endian format.
    # A HEIC file must contain a File Type Box (ftyp).
    # file conforms to all the requirements of the brands listed in the compatible_brands
    scan_file_type_box

    # file may be identified by MIME type of Annex C of ISO/IEC 23008-12.
    # the MIME indicates the nature and format of our assortment of bytes
    # note particularly that the brand 'mif1' doesn't mandate a MovieBox ("moov")
    if @compatible_brands.include?(MIF1_MARKER)
      scan_meta_level_box
    end
    if @compatible_brands.include?(MSF1_MARKER)
    end

    result = FormatParser::Image.new(
      format: :heic,
      width_px: @width,
      height_px: @height,
      # display_width_px: dw,
      # display_height_px: dh,
      # orientation: flat_exif.orientation_sym,
      # intrinsics: {exif: flat_exif},
      # content_type: JPEG_MIME_TYPE
      intrinsics: {
        'compatible_brands': @compatible_brands,
        'handler_type': @handler_type,
        'sub_items': @sub_items,
        'pixel_aspect_ratio': @pixel_aspect_ratio,
        'colour_info': @colour_info,
        'pixel_info': @pixel_info,
        'horizontal_offset': @horizontal_offset,
        'vertical_offset': @vertical_offset,
        'clean_aperture': @clean_aperture
      }
    )

    return result

    # if mif1 brand is present, the file may be identified by MIME type

  end

  def scan_file_type_box
    # the header is made by 4 bytes defining the box length and 4 bytes of the file type box marker.
    # HEIF Images start with the same marker, the usual "ftyp" box marker still as part of the 8 byte header
    # followed by the content, which the first 4 bytes must be the "heif" marker
    file_type_box_length = read_int_32
    return unless read_string(4) == FILE_TYPE_BOX_MARKER
    return unless read_string(4) == MAJOR_BRAND_MARKER
    minor_brand = read_string(4)

    # subtracting from the length box specified in the header the header itself (8 bytes = header length and length of ftyp)
    # then the length of the major and minor brand
    # what's left are the compatible brands
    data_left_length = file_type_box_length - HEADER_LENGTH - MAJOR_BRAND_MARKER.length - 4

    # all info are stored in bytes of 4
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
    # we start with the HDLR box..
    handler_length = read_int_32
    return unless read_string(4) == HANDLER_MARKER
    handler_length -= HEADER_LENGTH # subtract the header
    handler_start = @buf.pos
    # the handler type declare the type of metadata and thus the process by which the media-data in the track is presented
    # it also indicates the structure or format of the ‘meta’ box contents
    read_nil_version_and_flag
    pre_defined = read_string(4) # always 0 in the hdlr box
    @handler_type = read_string(4)
    @buf.seek(handler_start + handler_length) # the remaining part is reserved


    # ..continue looking for the IPRP box, containing info about the image itself
    next_box_length = read_int_32
    next_box = read_string(4)
    next_box_start_pos = @buf.pos
    while @buf.pos < @metadata_end_pos
      # box_length, box_name = next_box_container
      case next_box
      when ITEM_INFO_BOX
        read_item_info_box
      when ITEM_PROPERTIES_BOX
        read_item_properties_box(next_box_length)
      when next_box == ''
        break
      end
      next_box_length, next_box, next_box_start_pos = next_box_container(next_box_start_pos, next_box_length)
    end
  end

  #   # ..continue looking for the IPRP box, containing info about the image itself
  #   while @buf.pos < @metadata_end_pos
  #     box_length, box_name = next_box_container
  #     case box_name
  #     when ITEM_INFO_BOX
  #       read_item_info_box
  #     when ITEM_PROPERTIES_BOX
  #       read_item_properties_box(box_length)
  #     when box_name == ''
  #       break
  #     else
  #       @buf.seek(@buf.pos + box_length - HEADER_LENGTH)
  #     end
  #   end
  # end

  def read_item_info_box
    version = read_int_8
    safe_read(@buf, 3) # 0 flags
    if version == 0
      entry_count = read_int_16
    else
      entry_count = read_int_32
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
        return # wrong version according to standards, return
      end
      safe_skip(@buf, 2) # we don't care about the item_protection_index
      item_type = read_string(4)
      content_encoding = ''
      if item_type == MIME_MARKER
        content_encoding = (read_string(item_info_end_pos - @buf.pos)).delete!("\0") # need to remove the null-termination part
      end
      @sub_items << {'iteam_id': item_id, 'item_type': item_type, 'content_encoding': content_encoding}
      @buf.seek(item_info_end_pos) # we are not interested in anything else, go directly to the end of this 'infe' box
    }
  end

  def read_nil_version_and_flag
    version = safe_read(@buf, 1) # always 0 in this current box
    flags = safe_read(@buf, 3) # always 0 in this current box
  end

  def read_item_properties_box(box_length)
    end_of_box = @buf.pos + box_length - HEADER_LENGTH
    ipco_length = read_int_32
    return unless read_string(4) == ITEM_PROPERTIES_CONTAINER_BOX
    item_prop_length = read_int_32
    item_prop_name = read_string(4)
    item_prop_start_pos = @buf.pos
    while @buf.pos < end_of_box
      case item_prop_name
      when IMAGE_SPATIAL_EXTENTS_BOX
        read_nil_version_and_flag
        @width = read_int_32
        @height = read_int_32
      when PIXEL_ASPECT_RATIO_BOX
        h_spacing = read_int_32
        v_spacing = read_int_32
        @pixel_aspect_ratio = h_spacing.to_s + '/' + v_spacing.to_s
      when COLOUR_INFO_BOX
        @colour_info = []
        @colour_info << {
          'colour_primaries': read_int_16,
          'transfer_characteristics': read_int_16,
          'matrix_coefficients': read_int_16
        }
      when PIXEL_INFO_BOX
        @pixel_info = []
        read_nil_version_and_flag
        num_channels = read_int_8
        for channel in num_channels do
          @pixel_info << {
            "bits_in_channel_#{channel}": read_int_8
          }
        end
      when RELATIVE_LOCATION_BOX
        read_nil_version_and_flag
        @horizontal_offset = read_int_32
        @vertical_offset = read_int_32
      when CLEAN_APERTURE_BOX
        @clean_aperture = []
        @clean_aperture << {
          'clean_aperture_width_n': read_int_32,
          'clean_aperture_width_d': read_int_32,
          'clean_aperture_height_n': read_int_32,
          'clean_aperture_height_d': read_int_32,
          'horiz_off_n': read_int_32,
          'horiz_off_d': read_int_32,
          'vert_off_n': read_int_32,
          'vert_off_d': read_int_32
        }
      end
      item_prop_length, item_prop_name, item_prop_start_pos = next_box_container(item_prop_start_pos, item_prop_length)
    end
  end

  def next_meaningful_meta_byte
    while @buf.pos < @metadata_end_pos
      next_byte = read_string(4)
      if is_meaningful?(next_byte)
        return next_byte
      end
    end
  end

  # def seek_box(box_name)
  #   while @buf.pos < @metadata_end_pos
  #     next_box_length = read_int_32
  #     next_box_name = read_string(4)
  #     if next_box_name == box_name
  #       return (next_box_length - HEADER_LENGTH)
  #     else @buf.pos
  #   end
  # end

  # def next_box_container
  #   while @buf.pos < @metadata_end_pos
  #     next_box_length = read_int_32
  #     next_box_name = read_string(4)
  #     return next_box_length, next_box_name
  #   end
  # end

  def next_box_container(box_start_pos, box_length)
    @buf.seek(box_start_pos + box_length - HEADER_LENGTH)
    next_box_length = read_int_32
    next_box_name = read_string(4)
    return next_box_length, next_box_name, @buf.pos
  end


  def is_meaningful?(byte)
    byte != MEANINGLESS_BYTE
  end

  

  def likely_match?(filename)
    filename =~ /\.(heif|heic)$/i
  end

  FormatParser.register_parser(new, natures: :image, formats: :heif)
end