class FormatParser::CR2Parser
  include FormatParser::IOUtils

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    io.seek(8)
    cr2_check_bytes = io.read(2)

    # Check whether it's a CR2 file
    return unless cr2_check_bytes == 'CR'
  end
end
