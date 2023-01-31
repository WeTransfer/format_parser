require 'parsers/iso_base_media_file_format/decoder'

class FormatParser::MOVParser::Decoder < FormatParser::ISOBaseMediaFileFormat::Decoder
  protected

  def hdlr(size)
    fields = read_version_and_flags.merge({
      component_type: read_string(4),
      component_subtype: read_string(4),
      component_manufacturer: read_bytes(4),
      component_flags: read_bytes(4),
      component_flags_mask: read_bytes(4),
      component_name: read_string(size - 24)
    })
    [fields, nil]
  end

  def mvhd(_)
    fields = read_version_and_flags.merge({
      creation_time: read_int_32,
      modification_time: read_int_32,
      timescale: read_int_32,
      duration: read_int_32,
      rate: read_fixed_point_32,
      volume: read_fixed_point_16,
      matrix: skip_bytes(10) { read_matrix },
      preview_time: read_int_32,
      preview_duration: read_int_32,
      poster_time: read_int_32,
      selection_time: read_int_32,
      selection_duration: read_int_32,
      current_time: read_int_32,
      next_trak_id: read_int_32,
    })
    [fields, nil]
  end

  def tkhd(_)
    fields = read_version_and_flags.merge({
      creation_time: read_int_32,
      modification_time: read_int_32,
      track_id: read_int_32,
      duration: skip_bytes(4) { read_int_32 },
      layer: skip_bytes(8) { read_int_16 },
      alternate_group: read_int_16,
      volume: read_fixed_point_16,
      matrix: skip_bytes(2) { read_matrix },
      width: read_fixed_point_32,
      height: read_fixed_point_32
    })
    [fields, nil]
  end
end
