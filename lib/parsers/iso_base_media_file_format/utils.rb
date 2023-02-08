# frozen_string_literal: true

require 'matrix'

module FormatParser::ISOBaseMediaFileFormat::Utils
  def codecs(box_tree)
    video_trak_boxes(box_tree).flat_map do |trak_box|
      stsd_box = trak_box['mdia']['minf']['stbl']['stsd']
      stsd_box.children.map(&:type)
    end.uniq
  end

  def dimensions(box_tree)
    movie_matrix = box_tree.find { |box| box.type == 'moov' }['mvhd'][:matrix]
    extreme_coordinates = video_trak_boxes(box_tree).each_with_object({}) do |trak_box, extreme_coordinates|
      tkhd_box = trak_box['tkhd']
      next unless tkhd_box
      track_matrix = tkhd_box[:matrix]
      [
        [0, 0],
        [0, tkhd_box[:height]],
        [tkhd_box[:width], 0],
        [tkhd_box[:width], tkhd_box[:height]]
      ].each do |coordinates|
        x, y = (Matrix[[*coordinates, 1]] * track_matrix * movie_matrix).to_a[0][0..1]
        extreme_coordinates[:min_x] = x if !extreme_coordinates[:min_x] || x < extreme_coordinates[:min_x]
        extreme_coordinates[:max_x] = x if !extreme_coordinates[:max_x] || x > extreme_coordinates[:max_x]
        extreme_coordinates[:min_y] = y if !extreme_coordinates[:min_y] || y < extreme_coordinates[:min_y]
        extreme_coordinates[:max_y] = y if !extreme_coordinates[:max_y] || y > extreme_coordinates[:max_y]
      end
    end
    if extreme_coordinates.empty?
      [nil, nil]
    else
      [
        extreme_coordinates[:max_x] - extreme_coordinates[:min_x],
        extreme_coordinates[:max_y] - extreme_coordinates[:min_y]
      ]
    end
  end

  def duration(box_tree)
    mvhd_box = box_tree.find { |box| box.type == 'moov' }['mvhd']
    mvhd_box[:duration] / mvhd_box[:timescale].to_f
  end

  def frame_rate(box_tree)
    video_trak_boxes(box_tree).each_with_object([]) do |trak_box, frame_rates|
      mdia_box = trak_box['mdia']
      mdhd_box = mdia_box['mdhd']
      stts_box = mdia_box['minf']['stbl']['stts']

      timescale = mdhd_box[:timescale].to_f
      stts_entries = stts_box[:entries]

      frame_rate_for_entry = ->(stts_entry) { (timescale / stts_entry[:sample_delta]).truncate(2) }

      if stts_box[:entry_count] == 1
        # Constant frame rate
        frame_rates.push(frame_rate_for_entry[stts_entries[0]])
      else
        # Variable frame rate
        frame_rates.push(*(stts_entries.map { |entry| frame_rate_for_entry[entry] }))
      end
    end.uniq[0]
  end

  private

  # Find any and all `trak` boxes containing a video media handler (`hdlr` box with type `mhlr` and subtype `vide`).
  def video_trak_boxes(box_tree)
    moov_box = box_tree.find { |box| box.type == 'moov' }
    trak_boxes = moov_box.select_descendents(['trak'])
    trak_boxes.select do |trak_box|
      trak_box.select_descendents(['hdlr']).find do |hdlr_box|
        if hdlr_box.include?(:component_type) && hdlr_box.include?(:component_subtype) # MOV
          hdlr_box[:component_type] == 'mhlr' && hdlr_box[:component_subtype] == 'vide'
        else
          hdlr_box[:handler_type] == 'vide'
        end
      end
    end
  end
end
