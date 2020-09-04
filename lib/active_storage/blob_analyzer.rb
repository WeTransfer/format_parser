require_relative 'blob_io'

# An analyzer class that can be hooked to ActiveStorage, in order to enable
# FormatParser to do the blob analysis instead of ActiveStorage builtin-analyzers.
# Invoked if properly integrated in Rails initializer.

module FormatParser
  module ActiveStorage
    class BlobAnalyzer
      # Format parser is able to handle a lot of format so by default it will accept all files
      #
      # @return [Boolean, true] always return true
      def self.accept?(_blob)
        true
      end

      def initialize(blob)
        @blob = blob
      end

      # @return [Hash] file metadatas
      def metadata
        io = BlobIO.new(@blob)
        parsed_file = FormatParser.parse(io)

        if parsed_file
          # We symbolize keys because of existing output hash format of ImageAnalyzer
          parsed_file.as_json.symbolize_keys
        else
          logger.info "Skipping file analysis because FormatParser doesn't support the file"
        end
      end
    end
  end
end
