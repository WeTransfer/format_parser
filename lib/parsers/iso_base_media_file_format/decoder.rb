# This class provides generic methods for parsing file formats based on QuickTime-style "atoms", such as those seen in
# the ISO base media file format (ISO/IEC 14496-12), a.k.a MPEG-4, and those that extend it (MP4, CR3, HEIF, etc.).
#
# For more information on atoms, see https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html
# or https://b.goeswhere.com/ISO_IEC_14496-12_2015.pdf.
#
# TODO: The vast majority of the methods have been commented out here. This decision was taken to expedite the release
#   of support for the CR3 format, such that it was not blocked by the undertaking of testing this class in its
#   entirety. We should migrate existing formats that are based on the ISO base media file format and reintroduce these
#   methods with tests down-the-line.

module FormatParser
  module ISOBaseMediaFileFormat
    class Decoder
      include FormatParser::IOUtils

      class Atom < Struct.new(:type, :position, :size, :fields, :children)
        def initialize(type, position, size, fields = nil, children = nil)
          super
          self.fields ||= {}
          self.children ||= []
        end

        # Find and return the first descendent (using depth-first search) of a given type.
        #
        # @param [Array<String>] types
        # @return [Atom, nil]
        def find_first_descendent(types)
          children.each do |child|
            return child if types.include?(child.type)
            if (descendent = child.find_first_descendent(types))
              return descendent
            end
          end
          nil
        end

        # Find and return all descendents of a given type.
        #
        # @param [Array<String>] types
        # @return [Array<Atom>]
        def select_descendents(types)
          children.map do |child|
            descendents = child.select_descendents(types)
            types.include?(child.type) ? [child] + descendents : descendents
          end.flatten
        end
      end

      # @param [Integer] max_read
      # @param [IO, FormatParser::IOConstraint] io
      # @return [Array<Atom>]
      def build_atom_tree(max_read, io = nil)
        @buf = FormatParser::IOConstraint.new(io) if io
        raise ArgumentError, "IO missing - supply a valid IO object" unless @buf
        atoms = []
        max_pos = @buf.pos + max_read
        loop do
          break if @buf.pos >= max_pos
          atom = parse_atom
          break unless atom
          atoms << atom
        end
        atoms
      end

      protected

      # A mapping of atom types to their respective parser methods. Each method must take a single Integer parameter, size,
      # and return the atom's fields and children where appropriate as a Hash and Array of Atoms respectively.
      ATOM_PARSERS = {
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
        # 'ftyp' => :typ,
        # 'gitn' => :gitn,
        # 'hdlr' => :hdlr,
        # 'hmhd' => :hmhd,
        # 'iinf' => :iinf,
        # 'iloc' => :iloc,
        # 'infe' => :infe,
        # 'ipro' => :ipro,
        # 'iref' => :iref,
        # 'leva' => :leva,
        # 'mdhd' => :mdhd,
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
        # 'mvhd' => :mvhd,
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
        # 'stsd' => :stsd,
        # 'stsh' => :stsh,
        # 'stss' => :stss,
        # 'stsz' => :stsz,
        # 'stts' => :stts,
        # 'styp' => :typ,
        # 'stz2' => :stz2,
        # 'subs' => :subs,
        # 'tfra' => :tfra,
        # 'tkhd' => :tkhd,
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

      # Parse the atom at the IO's current position.
      #
      # @return [Atom, nil]
      def parse_atom
        position = @buf.pos

        size = read_int_32
        type = read_string(4)
        size = read_int_64 if size == 1
        body_size = size - (@buf.pos - position)
        next_atom_position = position + size

        if self.class::ATOM_PARSERS.include?(type)
          fields, children = method(self.class::ATOM_PARSERS[type]).call(body_size)
          if @buf.pos != next_atom_position
            # We should never end up in this state. If we do, it likely indicates a bug in the atom's parser method.
            warn("Unexpected IO position after parsing #{type} atom at position #{position}. Atom size: #{size}. Expected position: #{next_atom_position}. Actual position: #{@buf.pos}.")
            @buf.seek(next_atom_position)
          end
          Atom.new(type, position, size, fields, children)
        else
          skip_bytes(body_size)
          Atom.new(type, position, size)
        end
      rescue FormatParser::IOUtils::InvalidRead
        nil
      end

      # Parse any atom that serves as a container, with only children and no fields of its own.
      def container(size)
        [nil, build_atom_tree(size)]
      end

      # Parse only an atom's version and flags, skipping the remainder of the atom's body.
      def empty(size)
        fields = read_version_and_flags
        skip_bytes(size - 4)
        [fields, nil]
      end

      # Parse a binary XML atom.
      # def bxml(size)
      #   fields = read_version_and_flags.merge({
      #     data: (size - 4).times.map { read_int_8 }
      #   })
      #   [fields, nil]
      # end

      # Parse a chunk large offset atom.
      # def co64(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { chunk_offset: read_int_64 } }
      #   })
      #   [fields, nil]
      # end

      # Parse a copyright atom.
      # def cprt(size)
      #   fields = read_version_and_flags
      #   tmp = read_int_16
      #   fields.merge!({
      #     language: [(tmp >> 10) & 0x1F, (tmp >> 5) & 0x1F, tmp & 0x1F],
      #     notice: read_string(size - 6)
      #   })
      #   [fields, nil]
      # end

      # Parse a composition to decode atom.
      # def cslg(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     composition_to_dts_shift: version == 1 ? read_int_64 : read_int_32,
      #     least_decode_to_display_delta: version == 1 ? read_int_64 : read_int_32,
      #     greatest_decode_to_display_delta: version == 1 ? read_int_64 : read_int_32,
      #     composition_start_time: version == 1 ? read_int_64 : read_int_32,
      #     composition_end_time: version == 1 ? read_int_64 : read_int_32,
      #   })
      #   [fields, nil]
      # end

      # Parse a composition time to sample atom.
      # def ctts(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         sample_count: read_int_32,
      #         sample_offset: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a data reference atom.
      # def dref(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: read_int_32
      #   })
      #   [fields, build_atom_tree(size - 8)]
      # end

      # Parse a data reference URL entry atom.
      # def dref_url(size)
      #   fields = read_version_and_flags.merge({
      #     location: read_string(size - 4)
      #   })
      #   [fields, nil]
      # end

      # Parse a data reference URN entry atom.
      # def dref_urn(size)
      #   fields = read_version_and_flags
      #   name, location = read_bytes(size - 4).unpack('Z2')
      #   fields.merge!({
      #     name: name,
      #     location: location
      #   })
      #   [fields, nil]
      # end

      # Parse an FEC reservoir atom.
      # def fecr(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   entry_count = version == 0 ? read_int_16 : read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         item_id: version == 0 ? read_int_16 : read_int_32,
      #         symbol_count: read_int_8
      #       }
      #     end
      #   })
      # end

      # Parse an FD item information atom.
      # def fiin(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: read_int_16
      #   })
      #   [fields, build_atom_tree(size - 6)]
      # end

      # Parse a file reservoir atom.
      # def fire(_)
      #   fields = read_version_and_flags
      #   entry_count = version == 0 ? read_int_16 : read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         item_id: version == 0 ? read_int_16 : read_int_32,
      #         symbol_count: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a file partition atom.
      # def fpar(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     item_id: version == 0 ? read_int_16 : read_int_32,
      #     packet_payload_size: read_int_16,
      #     fec_encoding_id: skip_bytes(1) { read_int_8 },
      #     fec_instance_id: read_int_16,
      #     max_source_block_length: read_int_16,
      #     encoding_symbol_length: read_int_16,
      #     max_number_of_encoding_symbols: read_int_16,
      #   })
      #   # TODO: Parse scheme_specific_info, entry_count and entries { block_count, block_size }.
      #   skip_bytes(size - 20)
      #   skip_bytes(2) if version == 0
      #   [fields, nil]
      # end

      # Parse a group ID to name atom.
      # def gitn(size)
      #   fields = read_version_and_flags
      #   entry_count = read_int_16
      #   fields.merge!({
      #     entry_count: entry_count
      #   })
      #   # TODO: Parse entries.
      #   skip_bytes(size - 6)
      #   [fields, nil]
      # end

      # Parse a handler atom.
      # def hdlr(size)
      #   fields = read_version_and_flags.merge({
      #     handler_type: skip_bytes(4) { read_int_32 },
      #     name: skip_bytes(12) { read_string(size - 24) }
      #   })
      #   [fields, nil]
      # end

      # Parse a hint media header atom.
      # def hmhd(_)
      #   fields = read_version_and_flags.merge({
      #     max_pdu_size: read_int_16,
      #     avg_pdu_size: read_int_16,
      #     max_bitrate: read_int_32,
      #     avg_bitrate: read_int_32
      #   })
      #   skip_bytes(4)
      #   [fields, nil]
      # end

      # Parse an item info atom.
      # def iinf(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: version == 0 ? read_int_16 : read_int_32
      #   })
      #   [fields, build_atom_tree(size - 8)]
      # end

      # Parse an item location atom.
      # def iloc(_)
      #   fields = read_version_and_flags
      #   tmp = read_int_16
      #   item_count = if version < 2
      #     read_int_16
      #   elsif version == 2
      #     read_int_32
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
      #           read_int_16
      #         elsif version == 2
      #           read_int_32
      #         end
      #       }
      #       item[:construction_method] = read_int_16 & 0x7 if version == 1 || version == 2
      #       item[:data_reference_index] = read_int_16
      #       skip_bytes(base_offset_size) # TODO: Dynamically parse base_offset based on base_offset_size
      #       extent_count = read_int_16
      #       item[:extent_count] = extent_count
      #       # TODO: Dynamically parse extent_index, extent_offset and extent_length based on their respective sizes.
      #       skip_bytes(extent_count * (offset_size + length_size))
      #       skip_bytes(extent_count * index_size) if (version == 1 || version == 2) && index_size > 0
      #     end
      #   })
      # end

      # Parse an item info entry atom.
      # def infe(size)
      #   # TODO: This atom is super-complicated with optional and/or version-dependent fields and children.
      #   empty(size)
      # end

      # Parse an item protection atom.
      # def ipro(size)
      #   fields = read_version_and_flags.merge({
      #     protection_count: read_int_16
      #   })
      #   [fields, build_atom_tree(size - 6)]
      # end

      # Parse an item reference atom.
      # def iref(_)
      #   [read_version_and_flags, build_atom_tree(size - 4)]
      # end

      # Parse a level assignment atom.
      # def leva(_)
      #   fields = read_version_and_flags
      #   level_count = read_int_8
      #   fields.merge!({
      #     level_count: level_count,
      #     levels: level_count.times.map do
      #       track_id = read_int_32
      #       tmp = read_int_8
      #       assignment_type = tmp & 0x7F
      #       level = {
      #         track_id: track_id,
      #         padding_flag: tmp >> 7,
      #         assignment_type: assignment_type
      #       }
      #       if assignment_type == 0
      #         level[:grouping_type] = read_int_32
      #       elsif assignment_type == 1
      #         level.merge!({
      #           grouping_type: read_int_32,
      #           grouping_type_parameter: read_int_32
      #         })
      #       elsif assignment_type == 4
      #         level[:sub_track_id] = read_int_32
      #       end
      #       level
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a media header atom.
      # def mdhd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     creation_time: version == 1 ? read_int_64 : read_int_32,
      #     modification_time: version == 1 ? read_int_64 : read_int_32,
      #     timescale: read_int_32,
      #     duration: version == 1 ? read_int_64 : read_int_32,
      #   })
      #   tmp = read_int_16
      #   fields[:language] = [(tmp >> 10) & 0x1F, (tmp >> 5) & 0x1F, tmp & 0x1F]
      #   skip_bytes(2)
      #   [fields, nil]
      # end

      # Parse a movie extends header atom.
      # def mehd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:fragment_duration] = version == 1 ? read_int_64 : read_int_32
      #   [fields, nil]
      # end

      # Parse an metabox relation atom.
      # def mere(_)
      #   fields = read_version_and_flags.merge({
      #     first_metabox_handler_type: read_int_32,
      #     second_metabox_handler_type: read_int_32,
      #     metabox_relation: read_int_8
      #   })
      #   [fields, nil]
      # end

      # Parse a meta atom.
      # def meta(size)
      #   fields = read_version_and_flags
      #   [fields, build_atom_tree(size - 4)]
      # end

      # Parse a movie fragment header atom.
      # def mfhd(_)
      #   fields = read_version_and_flags.merge({
      #     sequence_number: read_int_32
      #   })
      #   [fields, nil]
      # end

      # Parse a movie fragment random access offset atom.
      # def mfro(_)
      #   fields = read_version_and_flags.merge({
      #     size: read_int_32
      #   })
      #   [fields, nil]
      # end

      # Parse a movie header atom.
      # def mvhd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     creation_time: version == 1 ? read_int_64 : read_int_32,
      #     modification_time: version == 1 ? read_int_64 : read_int_32,
      #     timescale: read_int_32,
      #     duration: version == 1 ? read_int_64 : read_int_32,
      #     rate: read_fixed_point_32,
      #     volume: read_fixed_point_16,
      #     matrix: skip_bytes(10) { read_matrix },
      #     next_trak_id: skip_bytes(24) { read_int_32 },
      #   })
      #   [fields, nil]
      # end

      # Parse a padding bits atom.
      # def padb(_)
      #   fields = read_version_and_flags
      #   sample_count = read_int_32
      #   fields.merge!({
      #     sample_count: sample_count,
      #     padding: ((sample_count + 1) / 2).times.map do
      #       tmp = read_int_8
      #       {
      #         padding_1: tmp >> 4,
      #         padding_2: tmp & 0x07
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a progressive download information atom.
      # def pdin(size)
      #   fields = read_version_and_flags.merge({
      #     entries: ((size - 4) / 8).times.map do
      #       {
      #         rate: read_int_32,
      #         initial_delay: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a primary item atom.
      # def pitm(_)
      #   fields = read_version_and_flags.merge({
      #     item_id: version == 0 ? read_int_16 : read_int_32
      #   })
      #   [fields, nil]
      # end

      # Parse a producer reference time atom.
      # def prft(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     reference_track_id: read_int_32,
      #     ntp_timestamp: read_int_64,
      #     media_time: version == 0 ? read_int_32 : read_int_64
      #   })
      #   [fields, nil]
      # end

      # Parse a sample auxiliary information offsets atom.
      # def saio(_)
      #   fields = read_version_and_flags
      #   version = field[:version]
      #   flags = fields[:flags]
      #   fields.merge!({
      #     aux_info_type: read_int_32,
      #     aux_info_type_parameter: read_int_32
      #   }) if flags & 0x1
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     offsets: entry_count.times.map { version == 0 ? read_int_32 : read_int_64 }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample auxiliary information sizes atom.
      # def saiz(_)
      #   fields = read_version_and_flags
      #   flags = fields[:flags]
      #   fields.merge!({
      #     aux_info_type: read_int_32,
      #     aux_info_type_parameter: read_int_32
      #   }) if flags & 0x1
      #   default_sample_info_size = read_int_8
      #   sample_count = read_int_32
      #   fields.merge!({
      #     default_sample_info_size: default_sample_info_size,
      #     sample_count: sample_count
      #   })
      #   fields[:sample_info_sizes] = sample_count.times.map { read_int_8 } if default_sample_info_size == 0
      #   [fields, nil]
      # end

      # Parse a sample to group atom.
      # def sbgp(_)
      #   fields = read_version_and_flags
      #   fields[:grouping_type] = read_int_32
      #   fields[:grouping_type_parameter] = read_int_32 if fields[:version] == 1
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         sample_count: read_int_32,
      #         group_description_index: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a scheme type atom.
      # def schm(_)
      #   fields = read_version_and_flags.merge({
      #     scheme_type: read_string(4),
      #     scheme_version: read_int_32,
      #   })
      #   fields[:scheme_uri] = (size - 12).times.map { read_int_8 } if flags & 0x1 != 0
      #   [fields, nil]
      # end

      # Parse an independent and disposable samples atom.
      # def sdtp(size)
      #   # TODO: Parsing this atom needs the sample_count from the sample size atom (`stsz`).
      #   empty(size)
      # end

      # Parse an FD session group atom.
      # def segr(_)
      #   num_session_groups = read_int_16
      #   fields = {
      #     num_session_groups: num_session_groups,
      #     session_groups: num_session_groups.times.map do
      #       entry_count = read_int_8
      #       session_group = {
      #         entry_count: entry_count,
      #         entries: entry_count.times.map { { group_id: read_int_32 } }
      #       }
      #       num_channels_in_session_group = read_int_16
      #       session_group.merge({
      #         num_channels_in_session_group: num_channels_in_session_group,
      #         channels: num_channels_in_session_group.times.map { { hint_track_id: read_int_32 } }
      #       })
      #     end
      #   }
      #   [fields, nil]
      # end

      # Parse a sample group description atom.
      # def sgpd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:grouping_type] = read_int_32
      #   fields[:default_length] = read_int_32 if version == 1
      #   fields[:default_sample_description_index] = read_int_32 if version >= 2
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       entry = {}
      #       entry[:description_length] = read_int_32 if version == 1 && fields[:default_length] == 0
      #       entry[:atom] = parse_atom
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a segment index atom.
      # def sidx(_)
      #   fields = read_version_and_flags.merge({
      #     reference_id: read_int_32,
      #     timescale: read_int_32
      #   })
      #   version = fields[:version]
      #   fields.merge!({
      #     earliest_presentation_time: version == 0 ? read_int_32 : read_int_64,
      #     first_offset: version == 0 ? read_int_32 : read_int_64,
      #   })
      #   reference_count = skip_bytes(2) { read_int_16 }
      #   fields.merge!({
      #     reference_count: reference_count,
      #     references: reference_count.times.map do
      #       tmp = read_int_32
      #       reference = {
      #         reference_type: tmp >> 31,
      #         referenced_size: tmp & 0x7FFFFFFF,
      #         subsegment_duration: read_int_32
      #       }
      #       tmp = read_int_32
      #       reference.merge({
      #         starts_with_sap: tmp >> 31,
      #         sap_type: (tmp >> 28) & 0x7,
      #         sap_delta_time: tmp & 0x0FFFFFFF
      #       })
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a sound media header atom.
      # def smhd(_)
      #   fields = read_version_and_flags.merge({
      #     balance: read_fixed_point_16,
      #   })
      #   skip_bytes(2)
      #   [fields, nil]
      # end

      # Parse a subsegment index atom.
      # def ssix(_)
      #   fields = read_version_and_flags
      #   subsegment_count = read_int_32
      #   fields.merge!({
      #     subsegment_count: subsegment_count,
      #     subsegments: subsegment_count.times.map do
      #       range_count = read_int_32
      #       {
      #         range_count: range_count,
      #         ranges: range_count.times.map do
      #           tmp = read_int_32
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

      # Parse a chunk offset atom.
      # def stco(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { chunk_offset: read_int_32 } }
      #   })
      #   [fields, nil]
      # end

      # Parse a degradation priority atom.
      # def stdp(size)
      #   # TODO: Parsing this atom needs the sample_count from the sample size atom (`stsz`).
      #   empty(size)
      # end

      # Parse a sub track information atom.
      # def stri(size)
      #   fields = read_version_and_flags.merge({
      #     switch_group: read_int_16,
      #     alternate_group: read_int_16,
      #     sub_track_id: read_int_32,
      #     attribute_list: ((size - 12) / 4).times.map { read_int_32 }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample to chunk atom.
      # def stsc(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         first_chunk: read_int_32,
      #         samples_per_chunk: read_int_32,
      #         sample_description_index: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a sample descriptions atom.
      # def stsd(size)
      #   fields = read_version_and_flags.merge({
      #     entry_count: read_int_32
      #   })
      #   [fields, build_atom_tree(size - 8)]
      # end

      # Parse a shadow sync sample atom.
      # def stsh(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map {
      #       {
      #         shadowed_sample_number: read_int_32,
      #         sync_sample_number: read_int_32
      #       }
      #     }
      #   })
      #   [fields, nil]
      # end

      # Parse a sync sample atom.
      # def stss(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map { { sample_number: read_int_32 } }
      #   })
      #   [fields, nil]
      # end

      # Parse a sample size atom.
      # def stsz(_)
      #   fields = read_version_and_flags
      #   sample_size = read_int_32
      #   sample_count = read_int_32
      #   fields.merge!({
      #     sample_size: sample_size,
      #     sample_count: sample_count,
      #   })
      #   fields[:entries] = sample_count.times.map { { entry_size: read_int_32 } } if sample_size == 0
      #   [fields, nil]
      # end

      # Parse a decoding time to sample atom.
      # def stts(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields.merge!({
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       {
      #         sample_count: read_int_32,
      #         sample_delta: read_int_32
      #       }
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a compact sample size atom.
      # def stz2(size)
      #   fields = read_version_and_flags.merge({
      #     field_size: skip_bytes(3) { read_int_8 },
      #     sample_count: read_int_32
      #   })
      #   # TODO: Handling for parsing entry sizes dynamically based on field size.
      #   skip_bytes(size - 12)
      #   [fields, nil]
      # end

      # Parse a sub-sample information atom.
      # def subs(_)
      #   fields = read_version_and_flags
      #   entry_count = read_int_32
      #   fields[:entries] = entry_count.times.map do
      #     sample_delta = read_int_32
      #     subsample_count = read_int_16
      #     {
      #       sample_delta: sample_delta,
      #       subsample_count: subsample_count,
      #       subsample_information: subsample_count.times.map do
      #         {
      #           subsample_size: version == 1 ? read_int_32 : read_int_16,
      #           subsample_priority: read_int_8,
      #           discardable: read_int_8,
      #           codec_specific_parameters: read_int_32
      #         }
      #       end
      #     }
      #   end
      #   [fields, nil]
      # end

      # Parse a track fragment random access atom.
      # def tfra(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields[:track_id] = read_int_32
      #   skip_bytes(3)
      #   tmp = read_int_8
      #   size_of_traf_number = (tmp >> 4) & 0x3
      #   size_of_trun_number = (tmp >> 2) & 0x3
      #   size_of_sample_number = tmp & 0x3
      #   entry_count = read_int_32
      #   fields.merge!({
      #     size_of_traf_number: size_of_traf_number,
      #     size_of_trun_number: size_of_trun_number,
      #     size_of_sample_number: size_of_sample_number,
      #     entry_count: entry_count,
      #     entries: entry_count.times.map do
      #       entry = {
      #         time: version == 1 ? read_int_64 : read_int_32,
      #         moof_offset: version == 1 ? read_int_64 : read_int_32
      #       }
      #       # TODO: Handling for parsing traf_number, trun_number and sample_number dynamically based on their sizes.
      #       skip_bytes(size_of_traf_number + size_of_trun_number + size_of_sample_number + 3)
      #       entry
      #     end
      #   })
      #   [fields, nil]
      # end

      # Parse a track header atom.
      # def tkhd(_)
      #   fields = read_version_and_flags
      #   version = fields[:version]
      #   fields.merge!({
      #     creation_time: version == 1 ? read_int_64 : read_int_32,
      #     modification_time: version == 1 ? read_int_64 : read_int_32,
      #     track_id: read_int_32,
      #     duration: skip_bytes(4) { version == 1 ? read_int_64 : read_int_32 },
      #     layer: skip_bytes(8) { read_int_16 },
      #     alternate_group: read_int_16,
      #     volume: read_fixed_point_16,
      #     matrix: skip_bytes(2) { read_matrix },
      #     width: read_fixed_point_32,
      #     height: read_fixed_point_32
      #   })
      #   [fields, nil]
      # end

      # Parse a track extends atom.
      # def trex(_)
      #   fields = read_version_and_flags.merge({
      #     track_id: read_int_32,
      #     default_sample_description_index: read_int_32,
      #     default_sample_duration: read_int_32,
      #     default_sample_size: read_int_32,
      #     default_sample_flags: read_int_32
      #   })
      #   [fields, nil]
      # end

      # Parse a track selection atom.
      # def tsel(size)
      #   fields = read_version_and_flags.merge({
      #     switch_group: read_int_32,
      #     attribute_list: ((size - 8) / 4).times.map { read_int_32 }
      #   })
      #   [fields, nil]
      # end

      # Parse a file/segment type compatibility atom.
      # def typ(size)
      #   compatible_brands_count = (size - 8) / 4
      #   fields = {
      #     major_brand: read_string(4),
      #     minor_version: read_int_32,
      #     compatible_brands: compatible_brands_count.times.map { read_string(4) }
      #   }
      #   [fields, nil]
      # end

      # Parse a UUID atom.
      def uuid(size)
        fields = { usertype: read_bytes(16).unpack('H*').first }
        skip_bytes(size - 16)
        [fields, nil]
      end

      # Parse a video media header atom.
      # def vmhd(_)
      #   fields = read_version_and_flags.merge({
      #     graphics_mode: read_int_16,
      #     op_color: (1..3).map { read_int_16 }
      #   })
      #   [fields, nil]
      # end

      # Parse an XML atom.
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
        9.times.map do |i|
          if i % 3 == 2
            read_fixed_point_32_2_30
          else
            read_fixed_point_32
          end
        end
      end

      # Parse an atom's version and flags.
      #
      # It's common for atoms to begin with a single byte representing the version followed by three bytes representing any
      # associated flags. Both of these are often 0.
      def read_version_and_flags
        {
          version: read_int_8,
          flags: read_bytes(3)
        }
      end
    end
  end
end
