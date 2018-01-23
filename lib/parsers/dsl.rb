module FormatParser
  # Small DSL to avoid repetitive code while defining a new parsers. Also, it can be leveraged by
  # third parties to define their own parsers.
  module DSL
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def formats(*registred_formats)
        __define(:formats, registred_formats)
      end

      def natures(*registred_natures)
        __define(:natures, registred_natures)
      end

      private

      def __define(name, value)
        throw ArgumentError('empty array') if value.empty?
        throw ArgumentError('requires array of symbols') if value.any? { |s| !s.is_a?(Symbol) }
        define_method(name) do
          value
        end
      end
    end
  end
end
