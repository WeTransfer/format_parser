class FormatParser::FDXParser
  include FormatParser::IOUtils

  def information_from_io(io)
    if xml_check(io)
      file_and_document_type = safe_read(io, 100)
      is_it_final_draft?(file_and_document_type)
    else
      return # Bail if it's not even XML
    end

    file_info = FormatParser::FileInformation.new(
      file_nature: :document,
      file_type: :fdx
    )
  end

  def xml_check(io)
    xml_check = safe_read(io, 5)
    xml_check == "<?xml" ? true : false
  end

  def is_it_final_draft?(file_and_document_type)
    if file_and_document_type.include?("FinalDraft")
      true
    else
      return
    end
  end

end