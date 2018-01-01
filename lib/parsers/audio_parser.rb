module FormatParser
  module Parsers
    class AudioParser
      PARSERS = [FormatParser::Parsers::Audio::AIFFParser].freeze

      def call(file)
        PARSERS.map(&:new).inject(nil) do |_, parser|
          # Mixed feelings here: It'd be wise to catch exceptions here,
          # to ensure that no parser is left behind after an error and
          # yet it shouldn't ignore every single exception.
          # As this is a gem, it doesn't make sense to have a monitoring system dep here.
          # Maybe, any raised exception'd be catched here, to be stored in an Array
          # and propagated only and only if there was not any result (nil) available?
          result = parser.call(file)
          break result unless result.nil?
        end
      end
    end
  end
end
