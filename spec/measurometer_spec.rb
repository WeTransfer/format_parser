require 'spec_helper'

describe Measurometer do
  RSpec::Matchers.define :include_counter_or_measurement_named do |named|
    match do |actual|
      actual.any? do |e|
        e[0] == named && e[1] > 0
      end
    end
  end

  it 'instruments a full cycle FormatParser.parse' do
    driver_class = Class.new do
      attr_accessor :timings, :counters, :distributions
      def instrument(block_name)
        s = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield.tap do
          delta = Process.clock_gettime(Process::CLOCK_MONOTONIC) - s
          @timings ||= []
          @timings << [block_name, delta * 1000]
        end
      end

      def add_distribution_value(value_path, value)
        @distributions ||= []
        @distributions << [value_path, value]
      end

      def increment_counter(value_path, value)
        @counters ||= []
        @counters << [value_path, value]
      end
    end

    instrumenter = driver_class.new
    described_class.drivers << instrumenter

    FormatParser.parse(File.open(fixtures_dir + 'JPEG/keynote_recognized_as_jpeg.key', 'rb'), results: :all)

    described_class.drivers.delete(instrumenter)
    expect(described_class.drivers).not_to include(instrumenter)

    # Legacy measurometer settings
    # Instrument things interesting in the global sense
    # instrument_instance_method(FormatParser::RemoteIO, :read, 'format_parser')
    # instrument_instance_method(Care::Cache, :read_page, 'format_parser')
    # 
    # # Instrument more specific things on a per-parser basis
    # instrument_instance_method(FormatParser::EXIFParser, :scan_image_tiff, 'format_parser')
    # instrument_instance_method(FormatParser::MOOVParser::Decoder, :extract_atom_stream, 'format_parser.parsers.MOOVParser')
  
    expect(instrumenter.counters).to include_counter_or_measurement_named('format_parser.detected_formats.zip')
    expect(instrumenter.counters).to include_counter_or_measurement_named('format_parser.parser.Care.page_reads_from_upsteam')
    expect(instrumenter.distributions).to include_counter_or_measurement_named('format_parser.ZIPParser.read_limiter.read_bytes')
    expect(instrumenter.timings).to include_counter_or_measurement_named('format_parser.Cache.read_page')
  end
end
