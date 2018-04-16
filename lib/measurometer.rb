class FormatParser::Measurometer
  class << self
    # Permits adding instrumentation drivers. Measurometer is 1-1 API
    # compatible with Appsignal, which we use a lot. So to magically
    # obtain all Appsignal instrumentation, add the Appsignal module
    # as a driver.
    #
    #   Measurometer.drivers << Appsignal
    def drivers
      @drivers ||= []
      @drivers
    end

    def instrument(block_name, &blk)
      return yield unless @drivers && @drivers.any? # The block wrapping business is not free
      @drivers.inject(blk) { |outer_block, driver|
        -> {
          driver.instrument(block_name, &outer_block)
        }
      }.call
    end

    def add_distribution_value(value_path, value)
      (@drivers || []).each { |d| d.add_distribution_value(value_path, value) }
      nil
    end

    def increment_counter(counter_path, by)
      (@drivers || []).each { |d| d.increment_counter(counter_path, by) }
      nil
    end

    def instrument_instance_method(target_class, method_to_instrument, path_prefix)
      short_class_name = target_class.to_s.split('::').last
      instrumentation_name = [path_prefix, short_class_name, method_to_instrument].join('.')
      instrumenter_module = Module.new do
        define_method(method_to_instrument) do |*any|
          ::FormatParser::Measurometer.instrument(instrumentation_name) { super(*any) }
        end
      end
      target_class.prepend(instrumenter_module)
    end
  end

  # Instrument things interesting in the global sense
  instrument_instance_method(FormatParser::RemoteIO, :read, 'format_parser')
  instrument_instance_method(Care::Cache, :read_page, 'format_parser')

  # Instrument more specific things on a per-parser basis
  instrument_instance_method(FormatParser::EXIFParser, :scan_image_tiff, 'format_parser')
  instrument_instance_method(FormatParser::MOOVParser::Decoder, :extract_atom_stream, 'format_parser.parsers.MOOVParser')
end
