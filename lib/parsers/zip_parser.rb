class FormatParser::ZIPParser
  require_relative 'zip_parser/file_reader'
  require_relative 'zip_parser/office_formats'

  include OfficeFormats

  def call(io)
    reader = FileReader.new
    entries = reader.read_zip_structure(io: FormatParser::IOConstraint.new(io))

    filenames_set = Set.new
    entries_archive = entries.map do |ze|
      ft = directory?(ze) ? :directory : :file
      decoded_filename = decode_filename(ze)
      filenames_set << decoded_filename
      FormatParser::Archive::Entry.new(type: ft, size: ze.uncompressed_size, filename: decoded_filename)
    end

    if office_document?(filenames_set)
      office_format = office_file_format_from_entry_set(filenames_set)
      FormatParser::Archive.new(nature: :document, format: office_format, entries: entries_archive)
    else
      FormatParser::Archive.new(nature: :archive,  format: :zip, entries: entries_archive)
    end
  rescue FileReader::Error
    # This is not a ZIP, or a broken ZIP.
    return
  end

  def directory?(zip_entry)
    # We can do a lap dance here and parse out the individual bit fields
    # from the external attributes, check the OS type that is in the entry
    # to see if it can be interpreted as UNIX or not, and generally have
    # heaps of fun. Instead, we will be frugal.
    zip_entry.filename.end_with?('/')
  end

  def decode_filename(zip_entry)
    # Check for the EFS bit in the general-purpose flags. If it is set,
    # the entry filename can be treated as UTF-8
    if zip_entry.gp_flags & 0b100000000000 == 0b100000000000
      zip_entry.filename.unpack('U*').pack('U*')
    else
      zip_entry.filename.encode(Encoding::UTF_8, undefined: :replace)
    end
  end

  FormatParser.register_parser self, natures: [:archive, :document], formats: :zip
end
