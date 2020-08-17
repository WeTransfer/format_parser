# Acts as a proxy to turn ActiveStorage file into IO object

module FormatParser
  module ActiveStorage
    class BlobIO
      # @param blob[ActiveStorage::Blob] the file with linked service
      # @return [BlobIO]
      def initialize(blob)
        @blob = blob
        @service = blob.service
        @pos = 0
      end

      # Emulates IO#read, but requires the number of bytes to read.
      # Rely on `ActiveStorage::Service.download_chunk` of each hosting type (local, S3, Azure, etc)
      #
      # @param n_bytes[Integer] how many bytes to read
      # @return [String] the read bytes
      def read(n_bytes)
        # HTTP ranges are exclusive.
        http_range = (@pos..(@pos + n_bytes - 1))
        body = @service.download_chunk(@blob.key, http_range)
        @pos += body.bytesize
        body.force_encoding(Encoding::ASCII_8BIT)
      end

      # Emulates IO#seek
      #
      # @param [Integer] offset size
      # @return [Integer] always return 0, `seek` only mutates `pos` attribute
      def seek(offset)
        @pos = offset
        0
      end

      # Emulates IO#size.
      #
      # @return [Integer] the size of the blob size from ActiveStorage
      def size
        @blob.byte_size
      end

      # Emulates IO#pos
      #
      # @return [Integer] the current offset (in bytes) of the io
      def pos
        @pos
      end
    end
  end
end
