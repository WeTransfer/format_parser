# frozen_string_literal: true

require 'stringio'

# A very barebones ZIP file reader
class FormatParser::ZIPParser::FileReader
  Error = Class.new(StandardError)
  ReadError = Class.new(Error)
  UnsupportedFeature = Class.new(Error)
  InvalidStructure = Class.new(Error)
  LocalHeaderPending = Class.new(Error) do
    def message
      'The compressed data offset is not available (local header has not been read)'
    end
  end
  MissingEOCD = Class.new(Error) do
    def message
      'Could not find the EOCD signature in the buffer - maybe a malformed ZIP file'
    end
  end
  InvalidCentralDirectory = Class.new(Error)

  C_UINT32LE = 'V'
  C_UINT16LE = 'v'
  C_UINT64LE = 'Q<'

  # To prevent too many tiny reads, read the maximum possible size of end of
  # central directory record upfront (all the fixed fields + at most 0xFFFF
  # bytes of the archive comment)
  MAX_END_OF_CENTRAL_DIRECTORY_RECORD_SIZE =
    begin
      4 + # Offset of the start of central directory
        4 + # Size of the central directory
        2 + # Number of files in the cdir
        4 + # End-of-central-directory signature
        2 + # Number of this disk
        2 + # Number of disk with the start of cdir
        2 + # Number of files in the cdir of this disk
        2 + # The comment size
        0xFFFF # Maximum comment size
    end

  # To prevent too many tiny reads, read the maximum possible size of the local file header upfront.
  # The maximum size is all the usual items, plus the maximum size
  # of the filename (0xFFFF bytes) and the maximum size of the extras (0xFFFF bytes)
  MAX_LOCAL_HEADER_SIZE =
    begin
      4 + # signature
        2 + # Version needed to extract
        2 + # gp flags
        2 + # storage mode
        2 + # dos time
        2 + # dos date
        4 + # CRC32
        4 + # Comp size
        4 + # Uncomp size
        2 + # Filename size
        2 + # Extra fields size
        0xFFFF + # Maximum filename size
        0xFFFF   # Maximum extra fields size
    end

  SIZE_OF_USABLE_EOCD_RECORD =
    begin
      4 + # Signature
        2 + # Number of this disk
        2 + # Number of the disk with the EOCD record
        2 + # Number of entries in the central directory of this disk
        2 + # Number of entries in the central directory total
        4 + # Size of the central directory
        4   # Start of the central directory offset
    end

  private_constant :C_UINT32LE, :C_UINT16LE, :C_UINT64LE, :MAX_END_OF_CENTRAL_DIRECTORY_RECORD_SIZE,
                   :MAX_LOCAL_HEADER_SIZE, :SIZE_OF_USABLE_EOCD_RECORD

  # Represents a file within the ZIP archive being read
  class ZipEntry
    include FormatParser::AttributesJSON

    # @return [Fixnum] bit-packed version signature of the program that made the archive
    attr_accessor :made_by

    # @return [Fixnum] ZIP version support needed to extract this file
    attr_accessor :version_needed_to_extract

    # @return [Fixnum] bit-packed general purpose flags
    attr_accessor :gp_flags

    # @return [Fixnum] Storage mode (0 for stored, 8 for deflate)
    attr_accessor :storage_mode

    # @return [Fixnum] the bit-packed DOS time
    attr_accessor :dos_time

    # @return [Fixnum] the bit-packed DOS date
    attr_accessor :dos_date

    # @return [Fixnum] the CRC32 checksum of this file
    attr_accessor :crc32

    # @return [Fixnum] size of compressed file data in the ZIP
    attr_accessor :compressed_size

    # @return [Fixnum] size of the file once uncompressed
    attr_accessor :uncompressed_size

    # @return [String] the filename
    attr_accessor :filename

    # @return [Fixnum] disk number where this file starts
    attr_accessor :disk_number_start

    # @return [Fixnum] internal attributes of the file
    attr_accessor :internal_attrs

    # @return [Fixnum] external attributes of the file
    attr_accessor :external_attrs

    # @return [Fixnum] at what offset the local file header starts
    #        in your original IO object
    attr_accessor :local_file_header_offset

    # @return [String] the file comment
    attr_accessor :comment

    # @return [Fixnum] at what offset you should start reading
    #       for the compressed data in your original IO object
    def compressed_data_offset
      @compressed_data_offset || raise(LocalHeaderPending)
    end

    # Tells whether the compressed data offset is already known for this entry
    # @return [Boolean]
    def known_offset?
      !@compressed_data_offset.nil?
    end

    # Tells whether the entry uses a data descriptor (this is defined
    # by bit 3 in the GP flags).
    def uses_data_descriptor?
      (gp_flags & 0x0008) == 0x0008
    end

    # Sets the offset at which the compressed data for this file starts in the ZIP.
    # By default, the value will be set by the Reader for you. If you use delayed
    # reading, you need to set it by using the `get_compressed_data_offset` on the Reader:
    #
    #     entry.compressed_data_offset = reader.get_compressed_data_offset(io: file,
    #            local_file_header_offset: entry.local_header_offset)
    def compressed_data_offset=(offset)
      @compressed_data_offset = offset.to_i
    end
  end

  # Parse an IO handle to a ZIP archive into an array of Entry objects.
  #
  # @param io[#tell, #seek, #read, #size] an IO-ish object
  # @return [Array<ZipEntry>] an array of entries within the ZIP being parsed
  def read_zip_structure(io:)
    zip_file_size = io.size
    eocd_offset = get_eocd_offset(io, zip_file_size)
    zip64_end_of_cdir_location = get_zip64_eocd_location(io, eocd_offset)
    num_files, cdir_location, cdir_size =
      if zip64_end_of_cdir_location
        num_files_and_central_directory_offset_zip64(io, zip64_end_of_cdir_location)
      else
        num_files_and_central_directory_offset(io, eocd_offset)
      end

    log { format('Located the central directory start at %d', cdir_location) }
    seek(io, cdir_location)

    # In zip_tricks we read the entire central directory _and_ enything behind it.
    # Strictly speaking, we should be able to read `cdir_size` bytes and not a byte more.
    # BUT! in format_parser we avoid unbounded reads, as a matter of fact they are forbidden.
    # So we will again limit ouselves to cdir_size, and we will take cushion of 1 KB.
    central_directory_str = io.read(cdir_size + 1024)
    raise InvalidCentralDirectory if central_directory_str.nil?

    central_directory_io = StringIO.new(central_directory_str)
    log do
      format(
        'Read %d bytes with central directory + EOCD record and locator',
        central_directory_str.bytesize)
    end

    entries = (0...num_files).map do |entry_n|
      offset_location = cdir_location + central_directory_io.pos
      log do
        format(
          'Reading the central directory entry %d starting at offset %d',
          entry_n, offset_location)
      end
      read_cdir_entry(central_directory_io)
    end

    entries
  end

  private

  def skip_ahead_2(io)
    skip_ahead_n(io, 2)
  end

  def skip_ahead_4(io)
    skip_ahead_n(io, 4)
  end

  def skip_ahead_8(io)
    skip_ahead_n(io, 8)
  end

  def seek(io, absolute_pos)
    io.seek(absolute_pos)
    unless absolute_pos == io.pos
      raise ReadError,
            "Expected to seek to #{absolute_pos} but only got to #{io.pos}"
    end
    nil
  end

  def assert_signature(io, signature_magic_number)
    readback = read_4b(io)
    if readback != signature_magic_number
      expected = '0x0' + signature_magic_number.to_s(16)
      actual = '0x0' + readback.to_s(16)
      raise InvalidStructure, "Expected signature #{expected}, but read #{actual}"
    end
  end

  def skip_ahead_n(io, n)
    pos_before = io.pos
    io.seek(io.pos + n)
    pos_after = io.pos
    delta = pos_after - pos_before
    unless delta == n
      raise ReadError, "Expected to seek #{n} bytes ahead, but could only seek #{delta} bytes ahead"
    end
    nil
  end

  def read_n(io, n_bytes)
    io.read(n_bytes).tap do |d|
      raise ReadError, "Expected to read #{n_bytes} bytes, but the IO was at the end" if d.nil?
      unless d.bytesize == n_bytes
        raise ReadError, "Expected to read #{n_bytes} bytes, read #{d.bytesize}"
      end
    end
  end

  def read_2b(io)
    read_n(io, 2).unpack(C_UINT16LE).shift
  end

  def read_4b(io)
    read_n(io, 4).unpack(C_UINT32LE).shift
  end

  def read_8b(io)
    read_n(io, 8).unpack(C_UINT64LE).shift
  end

  def read_cdir_entry(io)
    assert_signature(io, 0x02014b50)
    ZipEntry.new.tap do |e|
      e.made_by = read_2b(io)
      e.version_needed_to_extract = read_2b(io)
      e.gp_flags = read_2b(io)
      e.storage_mode = read_2b(io)
      e.dos_time = read_2b(io)
      e.dos_date = read_2b(io)
      e.crc32 = read_4b(io)
      e.compressed_size = read_4b(io)
      e.uncompressed_size = read_4b(io)
      filename_size = read_2b(io)
      extra_size = read_2b(io)
      comment_len = read_2b(io)
      e.disk_number_start = read_2b(io)
      e.internal_attrs = read_2b(io)
      e.external_attrs = read_4b(io)
      e.local_file_header_offset = read_4b(io)
      e.filename = read_n(io, filename_size)

      # Extra fields
      extras = read_n(io, extra_size)
      # Comment
      e.comment = read_n(io, comment_len)

      # Parse out the extra fields
      extra_table = parse_out_extra_fields(extras)

      # ...of which we really only need the Zip64 extra
      if zip64_extra_contents ||= extra_table[1]
        # If the Zip64 extra is present, we let it override all
        # the values fetched from the conventional header
        zip64_extra = StringIO.new(zip64_extra_contents)
        log do
          format(
            'Will read Zip64 extra data for %s, %d bytes',
            e.filename, zip64_extra.size)
        end
        # Now here be dragons. The APPNOTE specifies that
        #
        # > The order of the fields in the ZIP64 extended
        # > information record is fixed, but the fields will
        # > only appear if the corresponding Local or Central
        # > directory record field is set to 0xFFFF or 0xFFFFFFFF.
        #
        # It means that before we read this stuff we need to check if the previously-read
        # values are at overflow, and only _then_ proceed to read them. Bah.
        if e.uncompressed_size == 0xFFFFFFFF
          e.uncompressed_size = read_8b(zip64_extra)
        end
        if e.compressed_size == 0xFFFFFFFF
          e.compressed_size = read_8b(zip64_extra)
        end
        if e.local_file_header_offset == 0xFFFFFFFF
          e.local_file_header_offset = read_8b(zip64_extra)
        end
        # Disk number comes last and we can skip it anyway, since we do
        # not support multi-disk archives
      end
    end
  end

  def get_eocd_offset(file_io, zip_file_size)
    # Start reading from the _comment_ of the zip file (from the very end).
    # The maximum size of the comment is 0xFFFF (what fits in 2 bytes)
    implied_position_of_eocd_record = zip_file_size - MAX_END_OF_CENTRAL_DIRECTORY_RECORD_SIZE
    implied_position_of_eocd_record = 0 if implied_position_of_eocd_record < 0

    # Use a soft seek (we might not be able to get as far behind in the IO as we want)
    # and a soft read (we might not be able to read as many bytes as we want)
    file_io.seek(implied_position_of_eocd_record)
    str_containing_eocd_record = file_io.read(MAX_END_OF_CENTRAL_DIRECTORY_RECORD_SIZE)
    raise MissingEOCD unless str_containing_eocd_record

    eocd_idx_in_buf = locate_eocd_signature(str_containing_eocd_record)

    raise MissingEOCD unless eocd_idx_in_buf

    eocd_offset = implied_position_of_eocd_record + eocd_idx_in_buf
    log { format('Found EOCD signature at offset %d', eocd_offset) }

    eocd_offset
  end

  def all_indices_of_substr_in_str(of_substring, in_string)
    last_i = 0
    found_at_indices = []
    while last_i = in_string.index(of_substring, last_i)
      found_at_indices << last_i
      last_i += of_substring.bytesize
    end
    found_at_indices
  end

  def locate_eocd_signature(in_str)
    eocd_signature = [0x06054b50].pack('V')
    unpack_pattern = 'VvvvvVVv'
    minimum_record_size = 22
    str_size = in_str.bytesize
    indices = all_indices_of_substr_in_str(eocd_signature, in_str)
    indices.each do |check_at|
      maybe_record = in_str[check_at..str_size]
      # If the record is smaller than the minimum - we will never recover anything
      break if maybe_record.bytesize < minimum_record_size
      signature, *_rest, comment_size = maybe_record.unpack(unpack_pattern)

      # Check the only condition for the match
      if signature == 0x06054b50 && (maybe_record.bytesize - minimum_record_size) == comment_size
        return check_at # Found the EOCD marker location
      end
    end
    # If we haven't caught anything, return nil deliberately instead of returning the last statement
    nil
  end

  # Find the Zip64 EOCD locator segment offset. Do this by seeking backwards from the
  # EOCD record in the archive by fixed offsets
  def get_zip64_eocd_location(file_io, eocd_offset)
    zip64_eocd_loc_offset = eocd_offset
    zip64_eocd_loc_offset -= 4 # The signature
    zip64_eocd_loc_offset -= 4 # Which disk has the Zip64 end of central directory record
    zip64_eocd_loc_offset -= 8 # Offset of the zip64 central directory record
    zip64_eocd_loc_offset -= 4 # Total number of disks

    log do
      format(
        'Will look for the Zip64 EOCD locator signature at offset %d',
        zip64_eocd_loc_offset)
    end

    # If the offset is negative there is certainly no Zip64 EOCD locator here
    return unless zip64_eocd_loc_offset >= 0

    file_io.seek(zip64_eocd_loc_offset)
    assert_signature(file_io, 0x07064b50)

    log { format('Found Zip64 EOCD locator at offset %d', zip64_eocd_loc_offset) }

    disk_num = read_4b(file_io) # number of the disk
    raise UnsupportedFeature, 'The archive spans multiple disks' if disk_num != 0
    read_8b(file_io)
  rescue ReadError, InvalidStructure
    nil
  end

  #          num_files_and_central_directory_offset_zip64 is too high. [21.12/15]
  def num_files_and_central_directory_offset_zip64(io, zip64_end_of_cdir_location)
    seek(io, zip64_end_of_cdir_location)

    assert_signature(io, 0x06064b50)

    zip64_eocdr_size = read_8b(io)
    zip64_eocdr = read_n(io, zip64_eocdr_size) # Reading in bulk is cheaper
    zip64_eocdr = StringIO.new(zip64_eocdr)
    skip_ahead_2(zip64_eocdr) # version made by
    skip_ahead_2(zip64_eocdr) # version needed to extract

    disk_n = read_4b(zip64_eocdr) # number of this disk
    disk_n_with_eocdr = read_4b(zip64_eocdr) # number of the disk with the EOCDR
    if disk_n != disk_n_with_eocdr
      raise UnsupportedFeature, 'The archive spans multiple disks'
    end

    num_files_this_disk = read_8b(zip64_eocdr) # number of files on this disk
    num_files_total     = read_8b(zip64_eocdr) # files total in the central directory

    if num_files_this_disk != num_files_total
      raise UnsupportedFeature, 'The archive spans multiple disks'
    end

    log do
      format(
        'Zip64 EOCD record states there are %d files in the archive',
        num_files_total)
    end

    central_dir_size    = read_8b(zip64_eocdr) # Size of the central directory
    central_dir_offset  = read_8b(zip64_eocdr) # Where the central directory starts

    [num_files_total, central_dir_offset, central_dir_size]
  end

  def num_files_and_central_directory_offset(file_io, eocd_offset)
    seek(file_io, eocd_offset)

    # The size of the EOCD record is known upfront, so use a strict read
    eocd_record_str = read_n(file_io, SIZE_OF_USABLE_EOCD_RECORD)
    io = StringIO.new(eocd_record_str)

    assert_signature(io, 0x06054b50)
    skip_ahead_2(io) # number_of_this_disk
    skip_ahead_2(io) # number of the disk with the EOCD record
    skip_ahead_2(io) # number of entries in the central directory of this disk
    num_files = read_2b(io)   # number of entries in the central directory total
    cdir_size = read_4b(io)   # size of the central directory
    cdir_offset = read_4b(io) # start of central directorty offset
    [num_files, cdir_offset, cdir_size]
  end

  # Is provided as a stub to be overridden in a subclass if you need it. Will report
  # during various stages of reading. The log message is contained in the return value
  # of `yield` in the method (the log messages are lazy-evaluated).
  def log
    # $stderr.puts(yield)
  end

  def parse_out_extra_fields(extra_fields_str)
    extra_table = {}
    extras_buf = StringIO.new(extra_fields_str)
    until extras_buf.eof?
      extra_id = read_2b(extras_buf)
      extra_size = read_2b(extras_buf)
      extra_contents = read_n(extras_buf, extra_size)
      extra_table[extra_id] = extra_contents
    end
    extra_table
  end
end
