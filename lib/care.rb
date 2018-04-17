# Care (Caching Reader) makes it more efficient to feed a
# possibly remote IO to parsers that tend to read (and skip)
# in very small increments. This way, with a remote source that
# is only available via HTTP, for example, we can have less
# fetches and have them return more data for one fetch
class Care
  # Defines the size of a page in bytes that the Care will prefetch
  DEFAULT_PAGE_SIZE = 128 * 1024

  # Wraps any given IO with Care caching superpowers. Supports the subset
  # of IO declared in IOConstraint.
  class IOWrapper
    # Creates a new IOWrapper around the given source IO
    #
    # @param io[#seek, #pos, #size] the IO to wrap
    # @param page_size[Integer] the size of the cache page to use for this wrapper
    def initialize(io, page_size: DEFAULT_PAGE_SIZE)
      @cache = Cache.new(page_size)
      @io = io
      @pos = 0
    end

    # Returns the size of the resource contained in the IO
    #
    # @return Integer
    def size
      @io.size
    end

    # Seeks the IO to the given absolute offset from the start of the file/resource
    #
    # @param to[Integer] offset in the IO
    # @return Integer
    def seek(to)
      @pos = to
    end

    # Returns the current position/offset within the IO
    #
    # @return Integer
    def pos
      @pos
    end

    # Returns at most `n_bytes` of data from the IO or less if less data was available
    # before the EOF was hit
    #
    # @param n_bytes[Integer]
    # @return [String, nil] the content read from the IO or `nil` if no data was available
    def read(n_bytes)
      return '' if n_bytes == 0 # As hardcoded for all Ruby IO objects
      raise ArgumentError, "negative length #{n_bytes} given" if n_bytes < 0 # also as per Ruby IO objects
      read = @cache.byteslice(@io, @pos, n_bytes)
      return unless read && !read.empty?
      @pos += read.bytesize
      read
    end

    # Clears all the cached pages explicitly to help GC
    #
    # @return void
    def clear
      @cache.clear
    end

    # Clears all the cached pages explicitly to help GC, and
    # calls `#close` on the source IO if the IO responds to `#close`
    #
    # @return void
    def close
      clear
      @io.close if @io.respond_to?(:close)
    end
  end

  # Stores cached pages of data from the given IO as strings.
  # Pages are sized to be `page_size` or less (for the last page).
  class Cache
    # Initializes a new cache pages container with pages of given size
    def initialize(page_size = DEFAULT_PAGE_SIZE)
      @page_size = page_size.to_i
      raise ArgumentError, 'The page size must be a positive Integer' unless @page_size > 0
      @pages = {}
      @lowest_known_empty_page = nil
    end

    # Returns the maximum possible byte string that can be
    # recovered from the given `io` at the given offset.
    # If the IO has been exhausted, `nil` will be returned
    # instead. Will use the cached pages where available,
    # or fetch pages where necessary
    #
    # @param io[#seek, #read] the IO to read data from
    # @param at[Integer] at which offset we have to read
    # @param n_bytes[Integer] how many bytes we want to read/cache
    # @return [String, nil] the content read from the IO or `nil` if no data was available
    # @raise ArgumentError
    def byteslice(io, at, n_bytes)
      if n_bytes < 1
        raise ArgumentError, "The number of bytes to fetch must be a positive Integer, but was #{n_bytes}"
      end
      if at < 0
        raise ArgumentError, "Negative offsets are not supported (got #{at})"
      end

      first_page = at / @page_size
      last_page = (at + n_bytes) / @page_size

      relevant_pages = (first_page..last_page).map { |i| hydrate_page(io, i) }

      # Create one string combining all the pages which are relevant for
      # us - it is much easier to address that string instead of piecing
      # the output together page by page, and joining arrays of strings
      # is supposed to be optimized.
      slab = if relevant_pages.length > 1
        # If our read overlaps multiple pages, we do have to join them, this is
        # the general case
        relevant_pages.join
      else # We only have one page
        # Optimize a little. If we only have one page that we need to read from
        # - which is likely going to be the case *often* we can avoid allocating
        # a new string for the joined pages and juse use the only page
        # directly as the slab. Since it might contain a `nil` and we do
        # not join (which casts nils to strings) we take care of that too
        relevant_pages.first || ''
      end

      offset_in_slab = at % @page_size
      slice = slab.byteslice(offset_in_slab, n_bytes)

      # Returning an empty string from read() is very confusing for the caller,
      # and no builtins do this - if we are at EOF we should return nil
      slice if slice && !slice.empty?
    end

    # Clears the page cache of all strings with data
    #
    # @return void
    def clear
      @pages.clear
    end

    # Hydrates a page at the certain index or returns the contents of
    # that page if it is already in the cache
    #
    # @param io[IO] the IO to read from
    # @param page_i[Integer] which page (zero-based) to hydrate and return
    def hydrate_page(io, page_i)
      # Avoid trying to read the page if we know there is no content to fill it
      # in the underlying IO
      return if @lowest_known_empty_page && page_i >= @lowest_known_empty_page

      @pages[page_i] ||= read_page(io, page_i)
    end

    # We provide an overridden implementation of #inspect to avoid
    # printing the actual contents of the cached pages
    def inspect
      # Simulate the builtin object ID output https://stackoverflow.com/a/11765495/153886
      oid_str = (object_id << 1).to_s(16).rjust(16, '0')

      ivars = instance_variables
      ivars.delete(:@pages)
      ivars_str = ivars.map do |ivar|
        "#{ivar}=#{instance_variable_get(ivar).inspect}"
      end.join(' ')
      synthetic_vars = 'num_hydrated_pages=%d' % @pages.length
      '#<%s:%s %s %s>' % [self.class, oid_str, synthetic_vars, ivars_str]
    end

    # Reads the requested page from the given IO
    #
    # @param io[IO] the IO to read from
    # @param page_i[Integer] which page (zero-based) to read
    def read_page(io, page_i)
      io.seek(page_i * @page_size)
      read_result = io.read(@page_size)

      if read_result.nil?
        # If the read went past the end of the IO the read result will be nil,
        # so we know our IO is exhausted here
        if @lowest_known_empty_page.nil? || @lowest_known_empty_page > page_i
          @lowest_known_empty_page = page_i
        end
      elsif read_result.bytesize < @page_size
        # If we read less than we initially wanted we know there are no pages
        # to read following this one, so we can also optimize
        @lowest_known_empty_page = page_i + 1
      end

      read_result
    end
  end
end
