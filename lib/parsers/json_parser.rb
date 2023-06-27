class FormatParser::JSONParser
  include FormatParser::IOUtils
  require_relative 'json_parser/validator'

  JSON_MIME_TYPE = 'application/json'

  def likely_match?(filename)
    filename =~ /\.json$/i
  end

  def call(io)
    io = FormatParser::IOConstraint.new(io)
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
