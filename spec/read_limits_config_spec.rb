require 'spec_helper'

describe FormatParser::ReadLimitsConfig do
  it 'provides balanced values based on the initial byte read limit per parser' do
    config = FormatParser::ReadLimitsConfig.new(1024)

    expect(config.max_read_bytes_per_parser).to be_kind_of(Integer)
    expect(config.max_read_bytes_per_parser).to be > 0

    expect(config.cache_page_size).to be_kind_of(Integer)
    expect(config.cache_page_size).to be > 0

    expect(config.max_pagefaults_per_parser).to be_kind_of(Integer)
    expect(config.max_pagefaults_per_parser).to be > 0

    expect(config.max_reads_per_parser).to be_kind_of(Integer)
    expect(config.max_reads_per_parser).to be > 0

    expect(config.max_seeks_per_parser).to be_kind_of(Integer)
    expect(config.max_seeks_per_parser).to be > 0
  end
end
