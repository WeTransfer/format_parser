class FormatParser::MOOVParser
  include FormatParser::IOUtils
  require_relative 'moov_parser/decoder'

  # Maps values of the "ftyp" atom to something
  # we can reasonably call "file type" (something
  # usable as a filename extension)
  FTYP_MAP = {
    'qt  ' => :mov,
    'mp4 ' => :mp4,
    'm4a ' => :m4a,
  }

  # https://tools.ietf.org/html/rfc4337#section-2
  # There is also video/quicktime which we should be able to capture
  # here, but there is currently no detection for MOVs versus MP4s
  MP4_AU_MIME_TYPE = 'audio/mp4'
  MP4_MIXED_MIME_TYPE = 'video/mp4'

  def likely_match?(filename)
    filename =~ /\.(mov|m4a|ma4|mp4|aac|m4v)$/i
  end

  def call(io)
    return unless matches_moov_definition?(io)

    # Now we know we are in a MOOV, so go back and parse out the atom structure.
    # Parsing out the atoms does not read their contents - at least it doesn't
    # for the atoms we consider opaque (one of which is the "mdat" atom which
    # will be the prevalent part of the file body). We do not parse these huge
    # atoms - we skip over them and note where they are located.
    io.seek(0)

    # We have to tell the parser how far we are willing to go within the stream.
    # Knowing that we will bail out early anyway we will permit a large read. The
    # branch parse calls will know the maximum size to read from the parent atom
    # size that gets parsed just before.
    max_read_offset = 0xFFFFFFFF
    decoder = Decoder.new
    atom_tree = Measurometer.instrument('format_parser.Decoder.extract_atom_stream') do
      decoder.extract_atom_stream(io, max_read_offset)
    end

    ftyp_atom = decoder.find_first_atom_by_path(atom_tree, 'ftyp')
    file_type = ftyp_atom.field_value(:major_brand)

    # Try to find the width and height in the tkhd
    width, height = parse_dimensions(decoder, atom_tree)

    # Try to find the "topmost" duration (respecting edits)
    if mvhd = decoder.find_first_atom_by_path(atom_tree, 'moov', 'mvhd')
      timescale = mvhd.field_value(:tscale)
      duration = mvhd.field_value(:duration)
      media_duration_s = duration / timescale.to_f
    end

    # M4A only contains audio, while MP4 and friends can contain video.
    fmt = format_from_moov_type(file_type)
    if fmt == :m4a
      FormatParser::Audio.new(
        format: format_from_moov_type(file_type),
        media_duration_seconds: media_duration_s,
        content_type: MP4_AU_MIME_TYPE,
        intrinsics: atom_tree,
      )
    else
      FormatParser::Video.new(
        format: format_from_moov_type(file_type),
        width_px: width,
        height_px: height,
        frame_rate: parse_time_to_sample_atom(decoder, atom_tree)&.truncate(2),
        media_duration_seconds: media_duration_s,
        content_type: MP4_MIXED_MIME_TYPE,
        codecs: parse_sample_description_atom(decoder, atom_tree),
        intrinsics: atom_tree
      )
    end
  end

  private

  def format_from_moov_type(file_type)
    FTYP_MAP.fetch(file_type.downcase, :mov)
  end

  # The dimensions are located in tkhd atom, but in some files it is necessary
  # to get it below the video track, because it can have other tracks such as
  # audio which does not have the dimensions.
  # More details in https://developer.apple.com/library/archive/documentation/QuickTime/QTFF/QTFFChap2/qtff2.html#//apple_ref/doc/uid/TP40000939-CH204-DontLinkElementID_147
  #
  # Returns [width, height] if the dimension is found
  # Returns [nil, nil] if the dimension is not found
  def parse_dimensions(decoder, atom_tree)
    video_trak_atom = decoder.find_video_trak_atom(atom_tree)

    tkhd = begin
      if video_trak_atom
        decoder.find_first_atom_by_path([video_trak_atom], 'trak', 'tkhd')
      else
        decoder.find_first_atom_by_path(atom_tree, 'moov', 'trak', 'tkhd')
      end
    end

    if tkhd
      [tkhd.field_value(:track_width).first, tkhd.field_value(:track_height).first]
    else
      [nil, nil]
    end
  end

  # An MPEG4/MOV/M4A will start with the "ftyp" atom. The atom must have a length
  # of at least 8 (to accomodate the atom size and the atom type itself) plus the major
  # and minor version fields. If we cannot find it we can be certain this is not our file.
  def matches_moov_definition?(io)
    maybe_atom_size, maybe_ftyp_atom_signature = safe_read(io, 8).unpack('N1a4')
    minimum_ftyp_atom_size = 4 + 4 + 4 + 4
    maybe_atom_size >= minimum_ftyp_atom_size && maybe_ftyp_atom_signature == 'ftyp'
  end

  # Sample information is found in the 'time-to-sample' stts atom.
  # The media atom mdhd is needed too in order to get the movie timescale
  def parse_time_to_sample_atom(decoder, atom_tree)
    video_trak_atom = decoder.find_video_trak_atom(atom_tree)

    stts = if video_trak_atom
      decoder.find_first_atom_by_path([video_trak_atom], 'trak', 'mdia', 'minf', 'stbl', 'stts')
    else
      decoder.find_first_atom_by_path(atom_tree, 'moov', 'trak', 'mdia', 'minf', 'stbl', 'stts')
    end

    mdhd = if video_trak_atom
      decoder.find_first_atom_by_path([video_trak_atom], 'trak', 'mdia', 'mdhd')
    else
      decoder.find_first_atom_by_path(atom_tree, 'moov', 'trak', 'mdia', 'mdhd')
    end

    if stts && mdhd
      timescale = mdhd.atom_fields[:tscale]
      sample_duration = stts.field_value(:entries).dig(0, :sample_duration)
      if timescale.nil? || timescale == 0 || sample_duration.nil? || sample_duration == 0
        nil
      else
        timescale.to_f / sample_duration
      end
    else
      nil
    end
  end

  def parse_sample_description_atom(decoder, atom_tree)
    video_trak_atom = decoder.find_video_trak_atom(atom_tree)

    stsd = if video_trak_atom
      decoder.find_first_atom_by_path([video_trak_atom], 'trak', 'mdia', 'minf', 'stbl', 'stsd')
    else
      decoder.find_first_atom_by_path(atom_tree, 'moov', 'trak', 'mdia', 'minf', 'stbl', 'stsd')
    end

    if stsd
      stsd.field_value(:codecs)
    else
      nil
    end
  end

  FormatParser.register_parser new, natures: :video, formats: FTYP_MAP.values, priority: 1
end
