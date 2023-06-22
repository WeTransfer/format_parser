class FormatParser::JSONParser
  include FormatParser::IOUtils
  require_relative 'json_parser/validator'

  JSON_MIME_TYPE = 'application/json'

  # Detecting encoding: https://www.rfc-editor.org/rfc/rfc4627#section-3
  # parsing content

  def likely_match?(filename)
    filename =~ /\.json$/i
  end

  def call(io)

    # todo: should not raise errors
    io = FormatParser::IOConstraint.new(io)
    io.seek(0)
    validator = Validator.new(io)

    validator.validate

    FormatParser::Text.new(
      format: :json,
      content_type: JSON_MIME_TYPE,
    )
  rescue Validator::JSONParserError
    nil
  end
  FormatParser.register_parser new, natures: :text, formats: :json
end
