require_relative 'aac_parser/adts_header_info'
class FormatParser::AACParser
  include FormatParser::IOUtils

  AAC_MIME_TYPE = 'audio/aac'

  def likely_match?(filename)
    filename =~ /\.aac?$/i
  end

  def call(raw_io)
    io = FormatParser::IOConstraint.new(raw_io)
    header_bits = io.read(9).unpack('B*').first.split('')

    header_info = FormatParser::AdtsHeaderInfo.parse_adts_header(header_bits)
    return if header_info.nil?

    FormatParser::Audio.new(
      title: nil,
      album: nil,
      artist: nil,
      format: :aac,
      num_audio_channels: header_info.number_of_audio_channels,
      audio_sample_rate_hz: header_info.mpeg4_sampling_frequency,
      media_duration_seconds: nil,
      media_duration_frames: nil,
      intrinsics: nil,
      content_type: AAC_MIME_TYPE
    )
  end

  FormatParser.register_parser new, natures: :audio, formats: :aac
end
