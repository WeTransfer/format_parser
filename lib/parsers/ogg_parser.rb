# https://xiph.org/vorbis/doc/Vorbis_I_spec.pdf
# https://en.wikipedia.org/wiki/Ogg#Page_structure
class FormatParser::OggParser
  include FormatParser::IOUtils

  # The maximum size of an Ogg page is 65,307 bytes.
  MAX_POSSIBLE_PAGE_SIZE = 65307

  def call(io)
    # The format consists of chunks of data each called an "Ogg page". Each page
    # begins with the characters, "OggS", to identify the file as Ogg format.
    capture_pattern = safe_read(io, 4)
    return unless capture_pattern == 'OggS'

    io.seek(28) # skip not important bytes

    # Each header packet begins with the same header fields.
    #   1) packet_type: 8 bit value (the identification header is type 1)
    #   2) the characters v','o','r','b','i','s' as six octets
    packet_type, vorbis, _vorbis_version, channels, sample_rate = safe_read(io, 16).unpack('Ca6LCL')
    return unless packet_type == 1 && vorbis == 'vorbis'

    # Read the last page of the audio in order to calculate the duration.
    pos = io.size - MAX_POSSIBLE_PAGE_SIZE
    pos = 0 if pos < 0
    io.seek(pos)
    page = io.read(MAX_POSSIBLE_PAGE_SIZE)
    pos_of_the_last_page = page.rindex('OggS')

    return if pos_of_the_last_page.nil?

    header = page[pos_of_the_last_page..pos_of_the_last_page + 13]

    _capture_pattern, _version, _header_type, granule_position = header.unpack('a4CCQ')

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
