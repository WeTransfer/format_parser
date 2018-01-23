class FormatParser::FDXParser
  include FormatParser::IOUtils
  include FormatParser::DSL

  formats :fdx
  natures :document

  def call(io)
    return unless xml_check(io)
    file_and_document_type = safe_read(io, 100)
    file_type, document_type = check_for_document_type(file_and_document_type)
    return if file_type != :fdx
    FormatParser::Document.new(
      format: file_type,
      document_type: document_type
    )
  end

  def xml_check(io)
    xml_check = safe_read(io, 5)
    xml_check == '<?xml'
  end

  def check_for_document_type(file_and_document_type)
    sanitized_data = file_and_document_type.downcase
    if sanitized_data.include?('finaldraft') && sanitized_data.include?('script')
      return :fdx, :script
    else
      return
    end
  end
  FormatParser.register_parser_constructor self
end
