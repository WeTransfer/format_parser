# https://xiph.org/vorbis/doc/Vorbis_I_spec.pdf
# https://en.wikipedia.org/wiki/Ogg#Page_structure
class FormatParser::OggParser
  def call(io)
    # The format consists of chunks of data each called an "Ogg page". Each page
    # begins with the characters, "OggS", to identify the file as Ogg format.
    capture_pattern = io.read(4)
    return unless capture_pattern == 'OggS'

    io.seek(28) # skip not important bytes

    # Each header packet begins with the same header fields.
    #   1) packet_type: 8 bit value (the identification header is type 1)
    #   2) the characters v','o','r','b','i','s' as six octets
    packet_type, vorbis = io.read(7).unpack('Ca6')
    return unless packet_type == 1 && vorbis == 'vorbis'

    _vorbis_version, channels, sample_rate = io.read(9).unpack('LCL')

    # granule_position of the last page is required to calculate the duration.
    io.seek(0)
    granule_position = 0

    loop do
      chunk = io.read(27)

      _capture_pattern,
      _version,
      _header_type,
      granule_position,
      _bitstream_serial_number,
      _page_sequence_number,
      _checksum,
      page_segments = chunk.unpack('a4CCQVVVC')

      # page_segments is the number of segments the page contains. It is also
      # the size of the segment_table in bytes.

      segment_table = io.read(page_segments).unpack('C*')

      # segment_table is a vector of 8-bit values, each indicating the
      # length of the corresponding segment within the page body.

      page_body_size = segment_table.inject(:+)
      io.seek(io.pos + page_body_size)

      break if io.pos == io.size
    end

    duration = granule_position / sample_rate.to_f

    FormatParser::Audio.new(
      format: :ogg,
      audio_sample_rate_hz: sample_rate,
      num_audio_channels: channels,
      media_duration_seconds: duration
    )
  end

  FormatParser.register_parser self, natures: :audio, formats: :ogg
end
