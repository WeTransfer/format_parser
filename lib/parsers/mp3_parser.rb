class FormatParser::MP3Parser
  require_relative 'mp3_parser/id3_v1'
  require_relative 'mp3_parser/id3_v2'

  include FormatParser::IOUtils

  def information_from_io(io)
    # Read the last 128 bytes which might contain ID3v1
    id3_v1 = ID3V1.attempt_id3_v1_extraction(io)
    io.seek(0)
    id3_v2 = ID3V2.attempt_id3_v2_extraction(io)

    raise id3_v2.inspect
  end

  def parse_mpeg_frame(io)
  end


  FormatParser.register_parser_constructor self
end
