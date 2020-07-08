# based on https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/keys.rb#L116
# I chose to copy this method instead of adding activesupport as a dependency
# because we want to have the least number of dependencies
module FormatParser
  class HashUtils
    def self.deep_transform_keys(object, &block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[yield(key)] = deep_transform_keys(value, &block)
        end
      when Array
        object.map { |e| deep_transform_keys(e, &block) }
      else
        object
      end
    end
  end
end
