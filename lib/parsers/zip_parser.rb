class FormatParser::ZIPParser
  require_relative 'zip_parser/file_reader'

  def call(io)
    reader = FileReader.new
    entries = reader.read_zip_structure(io: FormatParser::IOConstraint.new(io))

    entries_archive = entries.map do |ze|
      FormatParser::Archive::Entry.new(type: :file, size: ze.uncompressed_size, filename: ze.filename)
    end

    FormatParser::Archive.new(format: :zip, entries: entries_archive)
  rescue FileReader::Error
    # This is not a ZIP, or a broken ZIP.
    return nil
  end
end
