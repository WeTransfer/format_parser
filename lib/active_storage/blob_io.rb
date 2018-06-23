module FormatParser
  module ActiveStorage
    class BlobIO
      def initialize(blob)
        @blob = blob
        @service = blob.service
        @pos = 0
        @remote_size = false
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
        raise 'Remote size not yet obtained, need to perform at least one read() to retrieve it' unless @remote_size
        @remote_size
      end

      def read(n_bytes)
        range_start = @pos
        range_end =  @pos + n_bytes - 1
        http_range = (range_start..range_end)

        # ActiveStorageAdapter#download_chunk method return '' when using range (start > end)
        # Raise invalid range exception if this is the case to recognise the real empty response
        raise ArgumentError, "Invalid range from #{range_start} to #{range_end}" if range_start > range_end

        begin
          body = @service.download_chunk(@blob.key, http_range)
        rescue Errno::ENOENT
          raise ArgumentError, "Key #{@blob.key} does not exist"
        rescue Errno::EINVAL
          # using negative range for example
          raise ArgumentError, "Invalid range from #{range_start} to #{range_end}"
        end

        if body
          @remote_size = body.bytesize
          @pos += body.bytesize
          body.force_encoding(Encoding::ASCII_8BIT)
        end
      end
    end
  end
end
