# frozen_string_literal: true

require 'matrix'

module FormatParser
  module ISOBaseMediaFileFormat
    module Utils

      IDENTITY_MATRIX = Matrix.identity(3)

      def dimensions(box_tree)
        moov_box = box_tree.find { |box| box.type == 'moov' }
        return unless moov_box
        movie_matrix = moov_box.first_child('mvhd')&.dig(:fields, :matrix) || IDENTITY_MATRIX
        extreme_coordinates = video_trak_boxes(box_tree).each_with_object({}) do |trak_box, extreme_coordinates|
          tkhd_box = trak_box.first_child('tkhd')
          next unless tkhd_box
          x = tkhd_box.fields[:width]
          y = tkhd_box.fields[:height]
          next unless x && y
          track_matrix = tkhd_box.fields[:matrix] || IDENTITY_MATRIX
          [[0, 0], [0, y], [x, 0], [x, y]].each do |coordinates|
            x, y = (Matrix[[*coordinates, 1]] * track_matrix * movie_matrix).to_a[0][0..1]
            extreme_coordinates[:min_x] = x if !extreme_coordinates[:min_x] || x < extreme_coordinates[:min_x]
            extreme_coordinates[:max_x] = x if !extreme_coordinates[:max_x] || x > extreme_coordinates[:max_x]
            extreme_coordinates[:min_y] = y if !extreme_coordinates[:min_y] || y < extreme_coordinates[:min_y]
            extreme_coordinates[:max_y] = y if !extreme_coordinates[:max_y] || y > extreme_coordinates[:max_y]
          end
        end
        unless extreme_coordinates.empty?
          [
            extreme_coordinates[:max_x] - extreme_coordinates[:min_x],
            extreme_coordinates[:max_y] - extreme_coordinates[:min_y]
          ]
        end
      end

      def duration(box_tree)
        mvhd_box = box_tree.find { |box| box.type == 'moov' }&.first_child('mvhd')
        return unless mvhd_box
        duration = mvhd_box.fields[:duration]
        timescale = mvhd_box.fields[:timescale]&.to_f
        duration / timescale if duration && timescale
      end

      def frame_rate(box_tree)
        video_trak_boxes(box_tree).each do |trak_box|
          mdhd_box = trak_box.first_descendent_by_path(%w[mdia mdhd])
          stts_box = trak_box.first_descendent_by_path(%w[mdia minf stbl stts])

          next unless mdhd_box && stts_box

          timescale = mdhd_box.fields[:timescale]&.to_f
          sample_delta = stts_box.dig(:fields, :entries, 0, :sample_delta)

          next unless timescale && sample_delta

          return (timescale / sample_delta).truncate(2)
        end
        nil
        # TODO: Properly account for and represent variable frame-rates.
      end

      def video_codecs(box_tree)
        video_trak_boxes(box_tree).flat_map do |trak_box|
          trak_box.all_descendents_by_path(%w[mdia minf stbl stsd]).flat_map { |stsd_box| stsd_box.children.map(&:type) }
        end.compact.uniq
      end

      private

      # Find any and all `trak` boxes containing a video media handler.
      def video_trak_boxes(box_tree)
        moov_box = box_tree.find { |box| box.type == 'moov' }
        return [] unless moov_box
        moov_box.all_children('trak').select do |trak_box|
          trak_box.all_descendents('hdlr').find do |hdlr_box|
            hdlr_fields = hdlr_box.fields
            if hdlr_fields.include?(:component_type) && hdlr_fields.include?(:component_subtype) # MOV
              hdlr_fields[:component_type] == 'mhlr' && hdlr_fields[:component_subtype] == 'vide'
            else
              hdlr_fields[:handler_type] == 'vide'
            end
          end
        end
      end
    end
  end
end
