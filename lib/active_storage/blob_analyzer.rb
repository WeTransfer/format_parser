require_relative 'blob_io'

# An analyzer class that can be hooked to ActiveStorage
# In order to enable FormatParser to do the blob anaysis instead of ActiveStorage built-in analyzers
# such as https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/analyzer/image_analyzer.rb
#
# Any ActiveStorage analyzer must implement these methods:
# - accept?
# - new
# - metadata
# For more information check https://github.com/rails/rails/blob/master/activestorage/lib/active_storage/analyzer.rb
module FormatParser
  module ActiveStorage
    class BlobAnalyzer
      # Assuming that we want this parser to always do analysis for any kind of blobs (image, video, document, etc..)
      def self.accept?(_blob)
        true
      end

      def initialize(blob)
        @io = BlobIO.new(blob)
      end

      def metadata
        result = FormatParser.parse(@io)
        result.nil? ? {} : result.as_json
      end
    end
  end
end
