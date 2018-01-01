class FormatParser::Result
  KEYS = %i[audio document image video].freeze

  def initialize(data)
    @data = data.select { |k, _| KEYS.include?(k) }
  end

  KEYS.each do |method|
    define_method(method) { @data[method] }
    define_method(:"#{method}?") { !@data[method].nil? }
  end

  def natures
    @data.reject { |_, v| v.nil? }.keys
  end
end
