class FormatParser::ReadLimitsConfig
  MAX_PAGE_FAULTS = 8

  def initialize(total_bytes_available_per_parser)
    @max_read_bytes_per_parser = total_bytes_available_per_parser.to_i
  end

  def max_read_bytes_per_parser
    @max_read_bytes_per_parser
  end

  def cache_page_size
    @max_read_bytes_per_parser / 4
  end

  def max_pagefaults_per_parser
    MAX_PAGE_FAULTS
  end

  def max_reads_per_parser
    # Imagine we read per single byte
    @max_read_bytes_per_parser / 2
  end

  def max_seeks_per_parser
    # Imagine we have to seek once per byte
    @max_read_bytes_per_parser / 2
  end
end
