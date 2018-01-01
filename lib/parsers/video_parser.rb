module FormatParser
  module Parsers
    class VideoParser
      # TODO: Implement video parsers.
      PARSERS = [].freeze

      def call(file)
        PARSERS.map(&:new).inject(nil) do |_, parser|
          result = parser.call(file)
          break result unless result.nil?
        end
      end
    end
  end
end
