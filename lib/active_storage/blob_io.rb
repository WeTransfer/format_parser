module FormatParser
  module ActiveStorage
    class BlobIO
      def initialize(blob)
        @blob = blob
        @service = blob.service
        @pos = 0
      end

      # Emulates IO#seek
      def seek(offset)
        @pos = offset
        0 # always return 0
      end

      # Emulates IO#pos
      def pos
        @pos
      end

      # Emulates IO#size.
      def size
        0
      end

      def read(n_bytes)
        http_range = (@pos..(@pos + n_bytes - 1))

        body = @service.download_chunk(@blob.key, http_range)

        body.force_encoding(Encoding::ASCII_8BIT)
      end
    end
  end
end
