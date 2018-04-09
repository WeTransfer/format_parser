# Care (Caching Reader) makes it more efficient to feed a
# possibly remote IO to parsers that tend to read (and skip)
# in very small increments. This way, with a remote source that
# is only available via HTTP, for example, we can have less
# fetches and have them return more data for one fetch
class Care
  DEFAULT_PAGE_SIZE = 64 * 1024

  class IOWrapper
    def initialize(io, cache = Cache.new(DEFAULT_PAGE_SIZE))
      @io = io
      @cache = cache
      @pos = 0
    end

    def size
      @io.size
    end

    def seek(to)
      @pos = to
    end

    def pos
      @pos
    end

    def read(n_bytes)
      return '' if n_bytes == 0 # As hardcoded for all Ruby IO objects
      raise ArgumentError, "negative length #{n_bytes} given" if n_bytes < 0 # also as per Ruby IO objects
      read = @cache.byteslice(@io, @pos, n_bytes)
      return unless read && !read.empty?
      @pos += read.bytesize
      read
    end

    def clear
      @cache.clear
    end

    def close
      clear
      @io.close if @io.respond_to?(:close)
    end
  end

  # Stores cached pages of data from the given IO as strings.
  # Pages are sized to be `page_size` or less (for the last page).
  class Cache
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

    def clear
      @pages.clear
    end

    def hydrate_page(io, page_i)
      # Avoid trying to read the page if we know there is no content to fill it
      # in the underlying IO
      return if @lowest_known_empty_page && page_i >= @lowest_known_empty_page

      @pages[page_i] ||= read_page(io, page_i)
    end

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
