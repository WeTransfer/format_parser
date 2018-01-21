# Handles decoding of MOV/MPEG4 atoms/boxes in a stream. Will recursively
# read atoms and parse their data fields if applicable. Also contains
# a few utility functions for finding atoms in a list etc.
class FormatParser::MOOVParser::Decoder

  class Atom < Struct.new(:at, :atom_size, :atom_type, :path, :children, :atom_fields)
    def to_s
      "%s (%s): %d bytes at offset %d" % [atom_type, path.join('.'), atom_size, at]
    end

    def field_value(data_field)
      (atom_fields || {}).fetch(data_field)
    end

    def as_json(*a)
      members.each_with_object({}) do |member_name, o|
        o[member_name] = public_send(member_name).as_json(*a)
      end
    end
  end

  # Atoms (boxes) that are known to only contain children, no data fields
  KNOWN_BRANCH_ATOM_TYPES = %w( moov mdia trak clip edts minf dinf stbl udta meta)

  # Atoms (boxes) that are known to contain both leaves and data fields
  KNOWN_BRANCH_AND_LEAF_ATOM_TYPES = %w( meta ) # the udta.meta thing used by iTunes

  # Limit how many atoms we scan in sequence, to prevent derailments
  MAX_ATOMS_AT_LEVEL = 128

  # Finds the first atom in the given Array of Atom structs that
  # matches the type, drilling down if a list of atom names is given
  def find_first_atom_by_path(atoms, *atom_types)
    type_to_find = atom_types.shift
    requisite = atoms.find {|e| e.atom_type == type_to_find }

    # Return if we found our match
    return requisite if atom_types.empty?

    # Return nil if we didn't find the match at this nesting level
    return nil unless requisite

    # ...otherwise drill further down
    find_first_atom_by_path(requisite.children || [], *atom_types)
  end

  def parse_ftyp_atom(io, atom_size)
    # Subtract 8 for the atom_size+atom_type,
    # and 8 once more for the major_brand and minor_version. The remaining
    # numbr of bytes is reserved for the compatible brands, 4 bytes per
    # brand.
    num_brands = (atom_size - 8 - 8) / 4
    {
      major_brand: read_bytes(io, 4),
      minor_version: read_binary_coded_decimal(io),
      compatible_brands: (1..num_brands).map { read_bytes(io, 4) },
    }
  end

  def parse_tkhd_atom(io, _)
    version = read_byte_value(io)
    is_v1 = version == 1
    {
      version: version,
      flags: read_chars(io, 3),
      ctime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      mtime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      trak_id: read_32bit_uint(io),
      reserved_1: read_chars(io, 4),
      duration: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      reserved_2: read_chars(io, 8),
      layer: read_16bit_uint(io),
      alternate_group: read_16bit_uint(io),
      volume: read_16bit_uint(io),
      reserved_3: read_chars(io, 2),
      matrix_structure: (1..9).map { read_32bit_fixed_point(io) },
      track_width: read_32bit_fixed_point(io),
      track_height: read_32bit_fixed_point(io),
    }
  end

  def parse_mdhd_atom(io, _)
    version = read_byte_value(io)
    is_v1 = version == 1
    {
      version: version,
      flags: read_bytes(io, 3),
      ctime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      mtime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      tscale: read_32bit_uint(io),
      duration: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      language: read_32bit_uint(io),
      quality: read_32bit_uint(io),
    }
  end

  def parse_vmhd_atom(io, _)
    {
      version: read_byte_value(io),
      flags: read_bytes(io, 3),
      graphics_mode: read_bytes(io, 2),
      opcolor_r: read_32bit_uint(io),
      opcolor_g: read_32bit_uint(io),
      opcolor_b: read_32bit_uint(io),
    }
  end

  def parse_mvhd_atom(io, _)
    version = read_byte_value(io)
    is_v1 = version == 1
    {
      version: version,
      flags: read_bytes(io, 3),
      ctime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      mtime: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      tscale: read_32bit_uint(io),
      duration: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
      preferred_rate: read_32bit_uint(io),
      reserved: read_bytes(io, 10),
      matrix_structure: (1..9).map { read_32bit_fixed_point(io) },
      preview_time: read_32bit_uint(io),
      preview_duration: read_32bit_uint(io),
      poster_time: read_32bit_uint(io),
      selection_time: read_32bit_uint(io),
      selection_duration: read_32bit_uint(io),
      current_time: read_32bit_uint(io),
      next_trak_id: read_32bit_uint(io),
    }
  end

  def parse_dref_atom(io, _)
    dict = {
      version: read_byte_value(io),
      flags: read_bytes(io, 3),
      num_entries: read_32bit_uint(io),
    }
    num_entries = dict[:num_entries]
    entries = (1..num_entries).map do
      entry = {
        size: read_32bit_uint(io),
        type: read_bytes(io, 4),
        version: read_bytes(io, 1),
        flags: read_bytes(io, 3),
      }
      entry[:data] = read_bytes(io, entry[:size] - 12)
      entry
    end
    dict[:entries] = entries
    dict
  end

  def parse_elst_atom(io, _)
    dict = {
      version: read_byte_value(io),
      flags: read_bytes(io, 3),
      num_entries: read_32bit_uint(io),
    }
    is_v1 = dict[:version] == 1 # Usual is 0, version 1 has 64bit durations
    num_entries = dict[:num_entries]
    entries = (1..num_entries).map do
      {
        track_duration: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
        media_time: is_v1 ? read_64bit_uint(io) : read_32bit_uint(io),
        media_rate: read_32bit_uint(io),
      }
    end
    dict[:entries] = entries
    dict
  end

  def parse_hdlr_atom(io, atom_size)
    sub_io = StringIO.new(io.read(atom_size - 8))
    {
      version: read_byte_value(sub_io),
      flags: read_bytes(sub_io, 3),
      component_type: read_bytes(sub_io, 4),
      component_subtype: read_bytes(sub_io, 4),
      component_manufacturer: read_bytes(sub_io, 4),
      component_flags: read_bytes(sub_io, 4),
      component_flags_mask: read_bytes(sub_io, 4),
      component_name: sub_io.read,
    }
  end

  def parse_atom_fields_per_type(io, atom_size, atom_type)
    if respond_to?("parse_#{atom_type}_atom", including_privates = true)
      send("parse_#{atom_type}_atom", io, atom_size)
    else
      nil # We can't look inside this leaf atom
    end
  end

  # Recursive descent parser - will drill down to atoms which
  # we know are permitted to have leaf/branch atoms within itself,
  # and will attempt to recover the data fields for leaf atoms
  def extract_atom_stream(io, max_read, current_branch = [])
    initial_pos = io.pos
    atoms = []
    MAX_ATOMS_AT_LEVEL.times do
      atom_pos = io.pos

      if atom_pos - initial_pos >= max_read
        break
      end

      size_and_type = io.read(4+4)
      if size_and_type.to_s.bytesize < 8
        break
      end

      atom_size, atom_type = size_and_type.unpack('Na4')

      # If atom_size is specified to be 1, it is larger than what fits into the
      # 4 bytes and we need to read it right after the atom type
      if atom_size == 1
        atom_size = read_64bit_uint(io)
      end

      children, fields = if KNOWN_BRANCH_AND_LEAF_ATOM_TYPES.include?(atom_type)
        parse_atom_children_and_data_fields(io, atom_size, atom_type)
      elsif KNOWN_BRANCH_ATOM_TYPES.include?(atom_type)
        [extract_atom_stream(io, atom_size - 8, current_branch + [atom_type]), nil]
      else # Assume leaf atom
        [nil, parse_atom_fields_per_type(io, atom_size, atom_type)]
      end

      atoms << Atom.new(atom_pos, atom_size, atom_type, current_branch + [atom_type], children, fields)

      io.seek(atom_pos + atom_size)
    end
    atoms
  end

  def read_16bit_fixed_point(io)
    whole, fraction = io.read(2).unpack('CC')
  end

  def read_32bit_fixed_point(io)
    whole, fraction = io.read(4).unpack('nn')
  end

  def read_chars(io, n)
    io.read(n)
  end

  def read_byte_value(io)
    io.read(1).unpack('C').first
  end

  def read_bytes(io, n)
    io.read(n)
  end

  def read_16bit_uint(io)
    io.read(2).unpack('n').first
  end

  def read_32bit_uint(io)
    io.read(4).unpack('N').first
  end

  def read_64bit_uint(io)
    io.read(8).unpack('Q>').first
  end

  def read_binary_coded_decimal(io)
    bcd_string = io.read(4)
    bcd_string.insert(0, '0') if bcd_string.length.odd?
    [bcd_string].pack('H*').unpack('C*')
  end
end
