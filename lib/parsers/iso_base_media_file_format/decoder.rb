# This class provides generic methods for parsing file formats based on QuickTime-style "boxes", such as those seen in
# the ISO base media file format (ISO/IEC 14496-12), a.k.a MPEG-4, and those that extend it (MP4, CR3, HEIF, etc.).
#
# For more information on boxes, see https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html
# or https://b.goeswhere.com/ISO_IEC_14496-12_2015.pdf.
#
# TODO: The vast majority of the methods have been commented out here. This decision was taken to expedite the release
#   of support for the CR3 format, such that it was not blocked by the undertaking of testing this class in its
#   entirety. We should migrate existing formats that are based on the ISO base media file format and reintroduce these
#   methods with tests down-the-line.

require 'matrix'

module FormatParser
  module ISOBaseMediaFileFormat
    class Decoder
      include FormatParser::IOUtils

      class Box < Struct.new(:type, :position, :size, :fields, :children)
        def initialize(type, position, size, fields = nil, children = nil)
          super
          self.fields ||= {}
          self.children ||= []
        end

        def [](index)
          if index.is_a?(Symbol)
            fields[index]
          elsif index.is_a?(String)
            children.find { |child| child.type == index }
          else
            children[index]
          end
        end

        # Find and return the first descendent (using depth-first search) of a given type.
        #
        # @param [Array<String>] types
        # @return [Box, nil]
        def find_first_descendent(types)
          children.each do |child|
            return child if types.include?(child.type)
            if (descendent = child.find_first_descendent(types))
              return descendent
            end
          end
          nil
        end

        def include?(key)
          if key.is_a?(Symbol)
            fields.include?(key)
          elsif key.is_a?(String)
            children.include?(key)
          else
            false
          end
        end

        # Find and return all descendents of a given type.
        #
        # @param [Array<String>] types
        # @return [Array<Box>]
        def select_descendents(types)
          children.map do |child|
            descendents = child.select_descendents(types)
            types.include?(child.type) ? [child] + descendents : descendents
          end.flatten
        end
      end

      # Attempt to build the ISOBMFF box tree represented in the given IO object.
      #
      # @param [Integer] max_read
      # @param [IO, StringIO, FormatParser::IOConstraint] io
      # @return [Array<Box>]
      def build_box_tree(max_read, io = nil)
        @buf = FormatParser::IOConstraint.new(io) if io
        raise ArgumentError, "IO missing - supply a valid IO object" unless @buf
        boxes = []
        max_pos = @buf.pos + max_read
        loop do
          break if @buf.pos >= max_pos
          box = parse_box
          break unless box
          boxes << box
        end
        boxes
      end

      protected

      # A mapping of box types to their respective parser methods. Each method must take a single Integer parameter, size,
      # and return the box's fields and children where appropriate as a Hash and Array of Boxes respectively.
      BOX_PARSERS = {
        # 'bxml' => :bxml,
        # 'co64' => :co64,
        # 'cprt' => :cprt,
        # 'cslg' => :cslg,
        # 'ctts' => :ctts,
        'dinf' => :container,
        # 'dref' => :dref,
        'edts' => :container,
        # 'fecr' => :fecr,
        # 'fiin' => :fiin,
        # 'fire' => :fire,
        # 'fpar' => :fpar,
        'ftyp' => :typ,
        # 'gitn' => :gitn,
        'hdlr' => :hdlr,
        # 'hmhd' => :hmhd,
        # 'iinf' => :iinf,
        # 'iloc' => :iloc,
        # 'infe' => :infe,
        # 'ipro' => :ipro,
        # 'iref' => :iref,
        # 'leva' => :leva,
        'mdhd' => :mdhd,
        'mdia' => :container,
        'meco' => :container,
        # 'mehd' => :mehd,
        # 'mere' => :mere,
        # 'meta' => :meta,
        # 'mfhd' => :mfhd,
        'mfra' => :container,
        # 'mfro' => :mfro,
        'minf' => :container,
        'moof' => :container,
        'moov' => :container,
        'mvex' => :container,
        'mvhd' => :mvhd,
        'nmhd' => :empty,
        # 'padb' => :padb,
        'paen' => :container,
        # 'pdin' => :pdin,
        # 'pitm' => :pitm,
        # 'prft' => :prft,
        # 'saio' => :saio,
        # 'saiz' => :saiz,
        # 'sbgp' => :sbgp,
        'schi' => :container,
        # 'schm' => :schm,
        # 'sdtp' => :sdtp,
        # 'segr' => :segr,
        # 'sgpd' => :sgpd,
        # 'sidx' => :sidx,
        'sinf' => :container,
        # 'smhd' => :smhd,
        # 'ssix' => :ssix,
        'stbl' => :container,
        # 'stco' => :stco,
        # 'stdp' => :stdp,
        'sthd' => :empty,
        'strd' => :container,
        # 'stri' => :stri,
        'strk' => :container,
        # 'stsc' => :stsc,
        'stsd' => :stsd,
        # 'stsh' => :stsh,
        # 'stss' => :stss,
        # 'stsz' => :stsz,
        'stts' => :stts,
        # 'styp' => :typ,
        # 'stz2' => :stz2,
        # 'subs' => :subs,
        # 'tfra' => :tfra,
        'tkhd' => :tkhd,
        'trak' => :container,
        # 'trex' => :trex,
        # 'tsel' => :tsel,
        'udta' => :container,
        # 'url ' => :dref_url,
        # 'urn ' => :dref_urn,
        'uuid' => :uuid,
        # 'vmhd' => :vmhd,
        # 'xml ' => :xml,
      }

      # Parse the box at the IO's current position.
      #
      # @return [Box, nil]
      def parse_box
        position = @buf.pos

        size = read_int
        type = read_string(4)
        size = read_int(n: 8) if size == 1
        body_size = size - (@buf.pos - position)
        next_box_position = position + size

        if self.class::BOX_PARSERS.include?(type)
          fields, children = method(self.class::BOX_PARSERS[type]).call(body_size)
          if @buf.pos != next_box_position
            # We should never end up in this state. If we do, it likely indicates a bug in the box's parser method.
            warn("Unexpected IO position after parsing #{type} box at position #{position}. Box size: #{size}. Expected position: #{next_box_position}. Actual position: #{@buf.pos}.")
            @buf.seek(next_box_position)
          end
          Box.new(type, position, size, fields, children)
        else
          skip_bytes(body_size)
          Box.new(type, position, size)
        end
      rescue FormatParser::IOUtils::InvalidRead
        nil
      end

      # Parse any box that serves as a container, with only children and no fields of its own.
      def container(size)
        [nil, build_box_tree(size)]
      end

      # Parse only an box's version and flags, skipping the remainder of the box's body.
      def empty(size)
        fields = read_version_and_flags
        skip_bytes(size - 4)
        [fields, nil]
      end

      # Parse a binary XML box.
      # def bxml(size)
      #   fields = read_version_and_flags.merge({
      #     data: (size - 4).times.map { read_int(n: 1) }
      #   })
      #   [fields, nil]
      # end

      # Parse a chunk large offset box.
      # def co64(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { chunk_offset: read_int(n: 8) } }
      #   })
      #   [fields, nil]
      # end

      # Parse a copyright box.
      # def cprt(size)
      #   fields = read_version_and_flags
      #   tmp = read_int(n: 2)
      #   fields.merge!({
      #     language: [(tmp >> 10) & 0x1F, (tmp >> 5) & 0x1F, tmp & 0x1F],
      #     notice: read_string(size - 6)
      #   })
      #   [fields, nil]
      # end

      # Parse a composition to decode box.
      # def cslg(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     composition_to_dts_shift: version == 1 ? read_int(n: 8) : read_int,
      #     least_decode_to_display_delta: version == 1 ? read_int(n: 8) : read_int,
      #     greatest_decode_to_display_delta: version == 1 ? read_int(n: 8) : read_int,
      #     composition_start_time: version == 1 ? read_int(n: 8) : read_int,
      #     composition_end_time: version == 1 ? read_int(n: 8) : read_int,
      #   })
      #   [fields, nil]
      # end

      # Parse a composition time to sample box.
      # def ctts(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         sample_count: read_int,
      #         sample_offset: read_int
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a data reference box.
      # def dref(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: read_int
      #   })
      #   [fields, build_box_tree(size - 8)]
      # end

      # Parse a data reference URL entry box.
      # def dref_url(size)
      #   fields = read_version_and_flags.merge({
      #     location: read_string(size - 4)
      #   })
      #   [fields, nil]
      # end

      # Parse a data reference URN entry box.
      # def dref_urn(size)
      #   fields = read_version_and_flags
      #   name, location = read_bytes(size - 4).unpack('Z2')
      #   fields.merge!({
      #     name: name,
      #     location: location
      #   })
      #   [fields, nil]
      # end

      # Parse an FEC reservoir box.
      # def fecr(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   entry_count = version == 0 ? read_int(n: 2) : read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         item_id: version == 0 ? read_int(n: 2) : read_int,
      #         symbol_count: read_int(n: 1)
      #       }
      #     end
      #   })
      # end

      # Parse an FD item information box.
      # def fiin(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: read_int(n: 2)
      #   })
      #   [fields, build_box_tree(size - 6)]
      # end

      # Parse a file reservoir box.
      # def fire(_)
      #   fields = read_version_and_flags
      #   entry_count = version == 0 ? read_int(n: 2) : read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         item_id: version == 0 ? read_int(n: 2) : read_int,
      #         symbol_count: read_int
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a file partition box.
      # def fpar(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     item_id: version == 0 ? read_int(n: 2) : read_int,
      #     packet_payload_size: read_int(n: 2),
      #     fec_encoding_id: skip_bytes(1) { read_int(n: 1) },
      #     fec_instance_id: read_int(n: 2),
      #     max_source_block_length: read_int(n: 2),
      #     encoding_symbol_length: read_int(n: 2),
      #     max_number_of_encoding_symbols: read_int(n: 2),
      #   })
      #   # TODO: Parse scheme_specific_info, entry_count and entries { block_count, block_size }.
      #   skip_bytes(size - 20)
      #   skip_bytes(2) if version == 0
      #   [fields, nil]
      # end

      # Parse a group ID to name box.
      # def gitn(size)
      #   fields = read_version_and_flags
      #   entry_count = read_int(n: 2)
      #   fields.merge!({
      #     entry_count: entry_count
      #   })
      #   # TODO: Parse entries.
      #   skip_bytes(size - 6)
      #   [fields, nil]
      # end

      # Parse a handler box.
      def hdlr(size)
        fields = read_version_and_flags.merge({
          handler_type: skip_bytes(4) { read_string(4) },
          name: skip_bytes(12) { read_string(size - 24) }
        })
        [fields, nil]
      end

      # Parse a hint media header box.
      # def hmhd(_)
      #   fields = read_version_and_flags.merge({
      #     max_pdu_size: read_int(n: 2),
      #     avg_pdu_size: read_int(n: 2),
      #     max_bitrate: read_int,
      #     avg_bitrate: read_int
      #   })
      #   skip_bytes(4)
      #   [fields, nil]
      # end

      # Parse an item info box.
      # def iinf(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: version == 0 ? read_int(n: 2) : read_int
      #   })
      #   [fields, build_box_tree(size - 8)]
      # end

      # Parse an item location box.
      # def iloc(_)
      #   fields = read_version_and_flags
      #   tmp = read_int(n: 2)
      #   item_count = if version < 2
      #     read_int(n: 2)
      #   elsif version == 2
      #     read_int
      #   end
      #   offset_size = (tmp >> 12) & 0x7
      #   length_size = (tmp >> 8) & 0x7
      #   base_offset_size = (tmp >> 4) & 0x7
      #   index_size = tmp & 0x7
      #   fields.merge!({
      #     offset_size: offset_size,
      #     length_size: length_size,
      #     base_offset_size: base_offset_size,
      #     item_count: item_count,
      #     items: item_count.times.map do
      #       item = {
      #         item_id: if version < 2
      #           read_int(n: 2)
      #         elsif version == 2
      #           read_int
      #         end
      #       }
      #       item[:construction_method] = read_int(n: 2) & 0x7 if version == 1 || version == 2
      #       item[:data_reference_index] = read_int(n: 2)
      #       skip_bytes(base_offset_size) # TODO: Dynamically parse base_offset based on base_offset_size
      #       extent_count = read_int(n: 2)
      #       item[:extent_count] = extent_count
      #       # TODO: Dynamically parse extent_index, extent_offset and extent_length based on their respective sizes.
      #       skip_bytes(extent_count * (offset_size + length_size))
      #       skip_bytes(extent_count * index_size) if (version == 1 || version == 2) && index_size > 0
      #     end
      #   })
      # end

      # Parse an item info entry box.
      # def infe(size)
      #   # TODO: This box is super-complicated with optional and/or version-dependent fields and children.
      #   empty(size)
      # end

      # Parse an item protection box.
      # def ipro(size)
      #   fields = read_version_and_flags.merge({
      #     protection_count: read_int(n: 2)
      #   })
      #   [fields, build_box_tree(size - 6)]
      # end

      # Parse an item reference box.
      # def iref(_)
      #   [read_version_and_flags, build_box_tree(size - 4)]
      # end

      # Parse a level assignment box.
      # def leva(_)
      #   fields = read_version_and_flags
      #   level_count = read_int(n: 1)
      #   fields.merge!({
      #     level_count: level_count,
      #     levels: level_count.times.map do
      #       track_id = read_int
      #       tmp = read_int(n: 1)
      #       assignment_type = tmp & 0x7F
      #       level = {
      #         track_id: track_id,
      #         padding_flag: tmp >> 7,
      #         assignment_type: assignment_type
      #       }
      #       if assignment_type == 0
      #         level[:grouping_type] = read_int
      #       elsif assignment_type == 1
      #         level.merge!({
      #           grouping_type: read_int,
      #           grouping_type_parameter: read_int
      #         })
      #       elsif assignment_type == 4
      #         level[:sub_track_id] = read_int
      #       end
      #       level
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a media header box.
      def mdhd(_)
        fields = read_version_and_flags
        version = fields[:version]
        fields.merge!({
          creation_time: version == 1 ? read_int(n: 8) : read_int,
          modification_time: version == 1 ? read_int(n: 8) : read_int,
          timescale: read_int,
          duration: version == 1 ? read_int(n: 8) : read_int,
        })
        tmp = read_int(n: 2)
        fields[:language] = [(tmp >> 10) & 0x1F, (tmp >> 5) & 0x1F, tmp & 0x1F]
        skip_bytes(2)
        [fields, nil]
      end

      # Parse a movie extends header box.
      # def mehd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:fragment_duration] = version == 1 ? read_int(n: 8) : read_int
      #   [fields, nil]
      # end

      # Parse an metabox relation box.
      # def mere(_)
      #   fields = read_version_and_flags.merge({
      #     first_metabox_handler_type: read_int,
      #     second_metabox_handler_type: read_int,
      #     metabox_relation: read_int(n: 1)
      #   })
      #   [fields, nil]
      # end

      # Parse a meta box.
      # def meta(size)
      #   fields = read_version_and_flags
      #   [fields, build_box_tree(size - 4)]
      # end

      # Parse a movie fragment header box.
      # def mfhd(_)
      #   fields = read_version_and_flags.merge({
      #     sequence_number: read_int
      #   })
      #   [fields, nil]
      # end

      # Parse a movie fragment random access offset box.
      # def mfro(_)
      #   fields = read_version_and_flags.merge({
      #     size: read_int
      #   })
      #   [fields, nil]
      # end

      # Parse a movie header box.
      def mvhd(_)
        fields = read_version_and_flags
        version = fields[:version]
        fields.merge!({
          creation_time: version == 1 ? read_int(n: 8) : read_int,
          modification_time: version == 1 ? read_int(n: 8) : read_int,
          timescale: read_int,
          duration: version == 1 ? read_int(n: 8) : read_int,
          rate: read_fixed_point(n: 4),
          volume: read_fixed_point(n: 2, signed: true),
          matrix: skip_bytes(10) { read_matrix },
          next_trak_id: skip_bytes(24) { read_int },
        })
        [fields, nil]
      end

      # Parse a padding bits box.
      # def padb(_)
      #   fields = read_version_and_flags
      #   sample_count = read_int
      #   fields.merge!({
      #     sample_count: sample_count,
      #     padding: ((sample_count + 1) / 2).times.map do
      #       tmp = read_int(n: 1)
      #       {
      #         padding_1: tmp >> 4,
      #         padding_2: tmp & 0x07
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a progressive download information box.
      # def pdin(size)
      #   fields = read_version_and_flags.merge({
      #     entries: ((size - 4) / 8).times.map do
      #       {
      #         rate: read_int,
      #         initial_delay: read_int
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a primary item box.
      # def pitm(_)
      #   fields = read_version_and_flags.merge({
      #     item_id: version == 0 ? read_int(n: 2) : read_int
      #   })
      #   [fields, nil]
      # end

      # Parse a producer reference time box.
      # def prft(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     reference_track_id: read_int,
      #     ntp_timestamp: read_int(n: 8),
      #     media_time: version == 0 ? read_int : read_int(n: 8)
      #   })
      #   [fields, nil]
      # end

      # Parse a sample auxiliary information offsets box.
      # def saio(_)
      #   fields = read_version_and_flags
      #   version = field[:version]
      #   flags = fields[:flags]
      #   fields.merge!({
      #     aux_info_type: read_int,
      #     aux_info_type_parameter: read_int
      #   }) if flags & 0x1
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     offsets: entry_count.times.map { version == 0 ? read_int : read_int(n: 8) }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample auxiliary information sizes box.
      # def saiz(_)
      #   fields = read_version_and_flags
      #   flags = fields[:flags]
      #   fields.merge!({
      #     aux_info_type: read_int,
      #     aux_info_type_parameter: read_int
      #   }) if flags & 0x1
      #   default_sample_info_size = read_int(n: 1)
      #   sample_count = read_int
      #   fields.merge!({
      #     default_sample_info_size: default_sample_info_size,
      #     sample_count: sample_count
      #   })
      #   fields[:sample_info_sizes] = sample_count.times.map { read_int(n: 1) } if default_sample_info_size == 0
      #   [fields, nil]
      # end

      # Parse a sample to group box.
      # def sbgp(_)
      #   fields = read_version_and_flags
      #   fields[:grouping_type] = read_int
      #   fields[:grouping_type_parameter] = read_int if fields[:version] == 1
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         sample_count: read_int,
      #         group_description_index: read_int
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a scheme type box.
      # def schm(_)
      #   fields = read_version_and_flags.merge({
      #     scheme_type: read_string(4),
      #     scheme_version: read_int,
      #   })
      #   fields[:scheme_uri] = (size - 12).times.map { read_int(n: 1) } if flags & 0x1 != 0
      #   [fields, nil]
      # end

      # Parse an independent and disposable samples box.
      # def sdtp(size)
      #   # TODO: Parsing this box needs the sample_count from the sample size box (`stsz`).
      #   empty(size)
      # end

      # Parse an FD session group box.
      # def segr(_)
      #   num_session_groups = read_int(n: 2)
      #   fields = {
      #     num_session_groups: num_session_groups,
      #     session_groups: num_session_groups.times.map do
      #       entry_count = read_int(n: 1)
      #       session_group = {
      #         entry_count: entry_count,
      #         entries: entry_count.times.map { { group_id: read_int } }
      #       }
      #       num_channels_in_session_group = read_int(n: 2)
      #       session_group.merge({
      #         num_channels_in_session_group: num_channels_in_session_group,
      #         channels: num_channels_in_session_group.times.map { { hint_track_id: read_int } }
      #       })
      #     end
      #   }
      #   [fields, nil]
      # end

      # Parse a sample group description box.
      # def sgpd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:grouping_type] = read_int
      #   fields[:default_length] = read_int if version == 1
      #   fields[:default_sample_description_index] = read_int if version >= 2
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       entry = {}
      #       entry[:description_length] = read_int if version == 1 && fields[:default_length] == 0
      #       entry[:box] = parse_box
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a segment index box.
      # def sidx(_)
      #   fields = read_version_and_flags.merge({
      #     reference_id: read_int,
      #     timescale: read_int
      #   })
      #   version = fields[:version]
      #   fields.merge!({
      #     earliest_presentation_time: version == 0 ? read_int : read_int(n: 8),
      #     first_offset: version == 0 ? read_int : read_int(n: 8),
      #   })
      #   reference_count = skip_bytes(2) { read_int(n: 2) }
      #   fields.merge!({
      #     reference_count: reference_count,
      #     references: reference_count.times.map do
      #       tmp = read_int
      #       reference = {
      #         reference_type: tmp >> 31,
      #         referenced_size: tmp & 0x7FFFFFFF,
      #         subsegment_duration: read_int
      #       }
      #       tmp = read_int
      #       reference.merge({
      #         starts_with_sap: tmp >> 31,
      #         sap_type: (tmp >> 28) & 0x7,
      #         sap_delta_time: tmp & 0x0FFFFFFF
      #       })
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a sound media header box.
      # def smhd(_)
      #   fields = read_version_and_flags.merge({
      #     balance: read_fixed_point(n: 2, signed: true),
      #   })
      #   skip_bytes(2)
      #   [fields, nil]
      # end

      # Parse a subsegment index box.
      # def ssix(_)
      #   fields = read_version_and_flags
      #   subsegment_count = read_int
      #   fields.merge!({
      #     subsegment_count: subsegment_count,
      #     subsegments: subsegment_count.times.map do
      #       range_count = read_int
      #       {
      #         range_count: range_count,
      #         ranges: range_count.times.map do
      #           tmp = read_int
      #           {
      #             level: tmp >> 24,
      #             range_size: tmp & 0x00FFFFFF
      #           }
      #         end
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a chunk offset box.
      # def stco(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { chunk_offset: read_int } }
      #   })
      #   [fields, nil]
      # end

      # Parse a degradation priority box.
      # def stdp(size)
      #   # TODO: Parsing this box needs the sample_count from the sample size box (`stsz`).
      #   empty(size)
      # end

      # Parse a sub track information box.
      # def stri(size)
      #   fields = read_version_and_flags.merge({
      #     switch_group: read_int(n: 2),
      #     alternate_group: read_int(n: 2),
      #     sub_track_id: read_int,
      #     attribute_list: ((size - 12) / 4).times.map { read_int }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample to chunk box.
      # def stsc(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         first_chunk: read_int,
      #         samples_per_chunk: read_int,
      #         sample_description_index: read_int
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a sample descriptions box.
      def stsd(size)
        fields = read_version_and_flags.merge({
          entry_count: read_int
        })
        [fields, build_box_tree(size - 8)]
      end

      # Parse a shadow sync sample box.
      # def stsh(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map {
      #       {
      #         shadowed_sample_number: read_int,
      #         sync_sample_number: read_int
      #       }
      #     }
      #   })
      #   [fields, nil]
      # end

      # Parse a sync sample box.
      # def stss(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { sample_number: read_int } }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample size box.
      # def stsz(_)
      #   fields = read_version_and_flags
      #   sample_size = read_int
      #   sample_count = read_int
      #   fields.merge!({
      #     sample_size: sample_size,
      #     sample_count: sample_count,
      #   })
      #   fields[:entries] = sample_count.times.map { { entry_size: read_int } } if sample_size == 0
      #   [fields, nil]
      # end

      # Parse a decoding time to sample box.
      def stts(_)
        fields = read_version_and_flags
        entry_count = read_int
        fields.merge!({
          entry_count: entry_count,
          entries: entry_count.times.map do
            {
              sample_count: read_int,
              sample_delta: read_int
            }
          end
        })
        [fields, nil]
      end

      # Parse a compact sample size box.
      # def stz2(size)
      #   fields = read_version_and_flags.merge({
      #     field_size: skip_bytes(3) { read_int(n: 1) },
      #     sample_count: read_int
      #   })
      #   # TODO: Handling for parsing entry sizes dynamically based on field size.
      #   skip_bytes(size - 12)
      #   [fields, nil]
      # end

      # Parse a sub-sample information box.
      # def subs(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int
      #   fields[:entries] = entry_count.times.map do
      #     sample_delta = read_int
      #     subsample_count = read_int(n: 2)
      #     {
      #       sample_delta: sample_delta,
      #       subsample_count: subsample_count,
      #       subsample_information: subsample_count.times.map do
      #         {
      #           subsample_size: version == 1 ? read_int : read_int(n: 2),
      #           subsample_priority: read_int(n: 1),
      #           discardable: read_int(n: 1),
      #           codec_specific_parameters: read_int
      #         }
      #       end
      #     }
      #   end
      #   [fields, nil]
      # end

      # Parse a track fragment random access box.
      # def tfra(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:track_id] = read_int
      #   skip_bytes(3)
      #   tmp = read_int(n: 1)
      #   size_of_traf_number = (tmp >> 4) & 0x3
      #   size_of_trun_number = (tmp >> 2) & 0x3
      #   size_of_sample_number = tmp & 0x3
      #   entry_count = read_int
      #   fields.merge!({
      #     size_of_traf_number: size_of_traf_number,
      #     size_of_trun_number: size_of_trun_number,
      #     size_of_sample_number: size_of_sample_number,
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       entry = {
      #         time: version == 1 ? read_int(n: 8) : read_int,
      #         moof_offset: version == 1 ? read_int(n: 8) : read_int
      #       }
      #       # TODO: Handling for parsing traf_number, trun_number and sample_number dynamically based on their sizes.
      #       skip_bytes(size_of_traf_number + size_of_trun_number + size_of_sample_number + 3)
      #       entry
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a track header box.
      def tkhd(_)
        fields = read_version_and_flags
        version = fields[:version]
        fields.merge!({
          creation_time: version == 1 ? read_int(n: 8) : read_int,
          modification_time: version == 1 ? read_int(n: 8) : read_int,
          track_id: read_int,
          duration: skip_bytes(4) { version == 1 ? read_int(n: 8) : read_int },
          layer: skip_bytes(8) { read_int(n: 2) },
          alternate_group: read_int(n: 2),
          volume: read_fixed_point(n: 2, signed: true),
          matrix: skip_bytes(2) { read_matrix },
          width: read_fixed_point(n: 4),
          height: read_fixed_point(n: 4)
        })
        [fields, nil]
      end

      # Parse a track extends box.
      # def trex(_)
      #   fields = read_version_and_flags.merge({
      #     track_id: read_int,
      #     default_sample_description_index: read_int,
      #     default_sample_duration: read_int,
      #     default_sample_size: read_int,
      #     default_sample_flags: read_int
      #   })
      #   [fields, nil]
      # end

      # Parse a track selection box.
      # def tsel(size)
      #   fields = read_version_and_flags.merge({
      #     switch_group: read_int,
      #     attribute_list: ((size - 8) / 4).times.map { read_int }
      #   })
      #   [fields, nil]
      # end

      # Parse a file/segment type compatibility box.
      def typ(size)
        compatible_brands_count = (size - 8) / 4
        fields = {
          major_brand: read_string(4),
          minor_version: read_int,
          compatible_brands: compatible_brands_count.times.map { read_string(4) }
        }
        [fields, nil]
      end

      # Parse a UUID box.
      def uuid(size)
        fields = { usertype: read_bytes(16).unpack('H*').first }
        skip_bytes(size - 16)
        [fields, nil]
      end

      # Parse a video media header box.
      # def vmhd(_)
      #   fields = read_version_and_flags.merge({
      #     graphics_mode: read_int(n: 2),
      #     op_color: (1..3).map { read_int(n: 2) }
      #   })
      #   [fields, nil]
      # end

      # Parse an XML box.
      # def xml(size)
      #   fields = read_version_and_flags.merge({
      #     xml: read_string(size - 4)
      #   })
      #   [fields, nil]
      # end

      # Parse a matrix.
      #
      # Matrices are 3×3 and encoded row-by-row as 32-bit fixed-point numbers divided as 16.16, except for the rightmost
      # column which is divided as 2.30.
      #
      # See https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap4/qtff4.html#//apple_ref/doc/uid/TP40000939-CH206-18737.
      def read_matrix
        Matrix.build(3) { |_, c| read_fixed_point(fractional_digits: c % 3 == 2 ? 30 : 16, signed: true) }
      end

      # Parse an box's version and flags.
      #
      # It's common for boxes to begin with a single byte representing the version followed by three bytes representing any
      # associated flags. Both of these are often 0.
      def read_version_and_flags
        {
          version: read_int(n: 1),
          flags: read_bytes(3)
        }
      end
    end
  end
end
