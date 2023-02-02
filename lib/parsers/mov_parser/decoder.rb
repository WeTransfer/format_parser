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
      creation_time: read_int,
      modification_time: read_int,
      timescale: read_int,
      duration: read_int,
      rate: read_fixed_point(n: 4),
      volume: read_fixed_point(n: 2, signed: true),
      matrix: skip_bytes(10) { read_matrix },
      preview_time: read_int,
      preview_duration: read_int,
      poster_time: read_int,
      selection_time: read_int,
      selection_duration: read_int,
      current_time: read_int,
      next_trak_id: read_int,
    })
    [fields, nil]
  end

  def tkhd(_)
    fields = read_version_and_flags.merge({
      creation_time: read_int,
      modification_time: read_int,
      track_id: read_int,
      duration: skip_bytes(4) { read_int },
      layer: skip_bytes(8) { read_int(n: 2) },
      alternate_group: read_int(n: 2),
      volume: read_fixed_point(n: 2, signed: true),
      matrix: skip_bytes(2) { read_matrix },
      width: read_fixed_point(n: 4),
      height: read_fixed_point(n: 4)
    })
    [fields, nil]
  end
end
