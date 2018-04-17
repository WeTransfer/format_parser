class FormatParser::Measurometer
  class << self
    # Permits adding instrumentation drivers. Measurometer is 1-1 API
    # compatible with Appsignal, which we use a lot. So to magically
    # obtain all Appsignal instrumentation, add the Appsignal module
    # as a driver.
    #
    #   Measurometer.drivers << Appsignal
    #
    # A driver must be reentrant and thread-safe - it should be possible
    # to have multiple `instrument` calls open from different threads at the
    # same time.
    # The driver must support the same interface as the Measurometer class
    # itself, minus the `drivers` and `instrument_instance_method` methods.
    #
    # @return Array
    def drivers
      @drivers ||= []
      @drivers
    end

    # Runs a given block within a cascade of `instrument` blocks of all the
    # added drivers.
    #
    #   Measurometer.instrument('do_foo') { compute! }
    #
    # unfolds to
    #   Appsignal.instrument('do_foo') do
    #     Statsd.timing('do_foo') do
    #       compute!
    #     end
    #   end
    #
    # A driver must be reentrant and thread-safe - it should be possible
    # to have multiple `instrument` calls open from different threads at the
    # same time.
    # The driver must support the same interface as the Measurometer class
    # itself, minus the `drivers` and `instrument_instance_method` methods.
    #
    # @param block_name[String] under which path to push the metric
    # @param blk[#call] the block to instrument
    # @return [Object] the return value of &blk
    def instrument(block_name, &blk)
      return yield unless @drivers && @drivers.any? # The block wrapping business is not free
      @drivers.inject(blk) { |outer_block, driver|
        -> {
          driver.instrument(block_name, &outer_block)
        }
      }.call
    end

    # Adds a distribution value (sample) under a given path
    #
    # @param value_path[String] under which path to push the metric
    # @param value[Numeric] distribution value
    # @return nil
    def add_distribution_value(value_path, value)
      (@drivers || []).each { |d| d.add_distribution_value(value_path, value) }
      nil
    end

    # Increment a named counter under a given path
    #
    # @param counter_path[String] under which path to push the metric
    # @param by[Integer] the counter increment to apply
    # @return nil
    def increment_counter(counter_path, by)
      (@drivers || []).each { |d| d.increment_counter(counter_path, by) }
      nil
    end

    # Wrap an anonymous module around an instance method in the given class to have
    # it instrumented automatically. The name of the measurement will be interpolated as:
    #
    #   "#{prefix}.#{rightmost_class_constant_name}.#{instance_method_name}"
    #
    # @param target_class[Class] the class to instrument
    # @param instance_method_name_to_instrument[Symbol] the method name to instrument
    # @param path_prefix[String] under which path to push the instrumented metric
    # @return void
    def instrument_instance_method(target_class, instance_method_name_to_instrument, path_prefix)
      short_class_name = target_class.to_s.split('::').last
      instrumentation_name = [path_prefix, short_class_name, instance_method_name_to_instrument].join('.')
      instrumenter_module = Module.new do
        define_method(instance_method_name_to_instrument) do |*any|
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
