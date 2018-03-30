# Based on an unscientific sample of 63 documents I could find on my hard drive,
# all docx/pptx/xlsx files contain, at the minimum, the following files:
# 
#   [Content_types].xml
#   _rels/.rels
#   docProps/core.xml
#   docPropx/app.xml
# 
# Additionally, per file type, they contain the following:
# 
#   word/document.xml
#   xl/workbook.xml
#   ppt/presentation.xml
# 
# These are sufficient to say with certainty that a ZIP is in fact an Office document.
# Also that unscientific sample revealed that I came to dislike MS Office so much as to
# only have 63 documents on my entire workstation.
#
# We do not perform the actual _decoding_ of the Office documents here, because to read
# their contents we need to:
#
# * inflate the compressed part files (potential for deflate bombs)
# * parse the document XML (potential for XML parser exploitation)
#
# which are real threats and require adequate mitigation. For our purposes the
# token detection of specific filenames should be enough to say with certainty
# that a document _is_ an Office document, and not just a ZIP.
module FormatParser::ZIPParser::OfficeFormats
  OFFICE_MARKER_FILES = %w(
    [Content_types].xml
    _rels/.rels
    docProps/core.xml
    docPropx/app.xml
  )

  def office_document?(filenames_set)
    filenames_set.subset?(Set.new(OFFICE_MARKER_FILES))
  end

  def office_file_format_from_entry_set(filenames_set)
    file_type = if filenames_set.include?('word/document.xml')
      :docx
    elsif filenames_set.include?('xl/workbook.xml')
      :xlsx
    elsif filenames_set.include?('ppt/presentation.xml')
      :pptx
    else
      :unknown
    end
    FormatParser::Document.new(format: file_type, page_count: 1)
  end
end
