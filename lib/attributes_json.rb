# Implements as_json as returning a Hash
# containing the return values of all the
# reader methods of an object that have
# associated pair writer methods.
#
#   class Foo
#     include AttributesJSON
#     attr_accessor :number_of_bars
#   end
#   the_foo = Foo.new
#   the_foo.number_of_bars = 42
#   the_foo.as_json #=> {:number_of_bars => 42}
module FormatParser::AttributesJSON

  # Implements a sane default `as_json` for an object
  # that accessors defined
  def as_json(root: false)
    h = {}
    h['nature'] = nature if respond_to?(:nature) # Needed for file info structs
    methods.grep(/\w\=$/).each_with_object(h) do |attr_writer_method_name, h|
      reader_method_name = attr_writer_method_name.to_s.gsub(/\=$/, '')
      value = public_send(reader_method_name)
      # When calling as_json on our members there is no need to pass the root: option given to us
      # by the caller
      h[reader_method_name] = value.respond_to?(:as_json) ? value.as_json : value
    end
    if root
      {'format_parser_file_info' => h}
    else
      h
    end
  end

  # Implements to_json with sane defaults, with or without arguments
  def to_json(*maybe_generator_state)
    as_json(root: false).to_json(*maybe_generator_state)
  end
end
