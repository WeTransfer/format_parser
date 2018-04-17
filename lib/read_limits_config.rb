class FormatParser::ReadLimitsConfig
  MAX_PAGE_FAULTS = 8

  def initialize(total_bytes_available_per_parser)
    @max_read_bytes_per_parser = total_bytes_available_per_parser.to_i
  end

  # Defines how many bytes each parser may request to read from the IO object given to it.
  # Is used to artificially limit unbounded reads in parsers that may wander off and
  # try to gulp in the file given to them indefinitely due to infinite loops or
  # wrongly implemented skips - or when handling data that has been deliberately
  # crafted in a way that can make a parser misbehave.
  # This is less strict than one could think - for example, the MOOV parser used for
  # Quicktime files will skip over the actual atom contents of the atoms, and will only
  # read atom headers - which stays under this limit for quite some time.
  def max_read_bytes_per_parser
    @max_read_bytes_per_parser
  end

  # How big should the cache page be. Each cache page read will incur one `#read`
  # on the underlying IO object, remote or local
  def cache_page_size
    @max_read_bytes_per_parser / 4
  end

  # Each parser can incur HTTP requests when performing `parse_http`. This constant
  # sets the maximum number of pages each parser is allowed to hit that have not
  # been fetched previously and are not stored in the cache. For example, with most
  # formats the first cache page and the last cache page - tail and head of the file,
  # respectively - will be available right after the first parser retreives some data.
  # The second parser accessing the same data will reuse the in-memory cache.
  def max_pagefaults_per_parser
    MAX_PAGE_FAULTS
  end

  # Defines how many `#read` calls each parser may perform on the IO object given to it.
  # Is used to artificially limit unbounded reads in parsers that may wander off and
  # try to gulp in the file given to them indefinitely due to infinite loops or
  # wrongly implemented skips - or when handling data that has been deliberately
  # crafted in a way that can make a parser misbehave.
  def max_reads_per_parser
    # Imagine we read per single byte
    @max_read_bytes_per_parser / 2
  end

  # Defines how many `#seek` calls each parser may perform on the IO object given to it.
  # Is used to artificially limit unbounded reads in parsers that may wander off and
  # try to gulp in the file given to them indefinitely due to infinite loops or
  # wrongly implemented skips - or when handling data that has been deliberately
  # crafted in a way that can make a parser misbehave.
  def max_seeks_per_parser
    # Imagine we have to seek once per byte
    @max_read_bytes_per_parser / 2
  end
end
