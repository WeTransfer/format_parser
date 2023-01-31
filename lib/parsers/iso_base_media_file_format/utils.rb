# frozen_string_literal: true

module FormatParser::ISOBaseMediaFileFormat::Utils
  def codecs(box_tree)
    stsd_box = video_trak_box(box_tree)['mdia']['minf']['stbl']['stsd']
    stsd_box.children.map(&:type)
  end

  def dimensions(box_tree)
    # We can grab the dimensions from the `tkhd` box within the video `trak` box.
    # TODO: Account for multiple video tracks.
    # TODO: Apply matrix transformations.
    tkhd_box = video_trak_box(box_tree)['tkhd']
    if tkhd_box
      [tkhd_box[:width], tkhd_box[:height]]
    else
      [nil, nil]
    end
  end

  def duration(box_tree)
    mvhd_box = box_tree.find { |box| box.type == 'moov' }['mvhd']
    mvhd_box[:duration] / mvhd_box[:timescale].to_f
  end

  def frame_rate(box_tree)
    mdia_box = video_trak_box(box_tree)['trak']['mdia']
    mdhd_box = mdia_box['mdhd']
    stts_box = mdia_box['minf']['stbl']['stts']

    timescale = mdhd_box[:timescale].to_f
    stts_entries = stts_box[:entries]

    if stts_box[:entry_count] == 1
      # Constant frame rate
      (timescale / stts_entries[0][:sample_delta]).truncate(2)
    else
      # Variable frame rate
      stts_entries.map { |entry| (timescale / entry[:sample_delta]).truncate(2) }.uniq
    end
  end

  private

  def video_trak_box(box_tree)
    # Try to find a `trak` box containing a video media handler (`hdlr` box with type 'mhlr' and subtype 'vide'). If we
    # can't find one, just use the first one (there is always at least one).
    moov_box = box_tree.find { |box| box.type == 'moov' }
    moov_box.select_descendents(['trak']).find do |trak_box|
      trak_box.select_descendents(['hdlr']).find do |hdlr_box|
        hdlr_box[:component_type] == 'mhlr' && hdlr_box[:component_subtype] == 'vide'
      end
    end || moov_box['trak']
  end
end
