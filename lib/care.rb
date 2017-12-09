# Care (Caching Reader) makes it more efficient to feed a
# possibly remote IO to parsers that tend to read (and skip)
# in very small increments. This way, with a remote source that
# is only available via HTTP, for example, we can have less
# fetches and perform them in larger chunks
class Care
  DEFAULT_PAGE_SIZE = 512 * 1024

  class IOWrapper
    def initialize(io, cache=Cache.new(DEFAULT_PAGE_SIZE))
      @io, @cache = io, cache
      @pos = 0
    end

    def seek(to)
      @pos = to
    end

    def read(n_bytes)
      read = @cache.byteslice(@io, @pos, n_bytes)
      return nil unless read && !read.empty?
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

  # Stores slabs from a given source in contiguous pages.
  class Cache
    def initialize(page_size = DEFAULT_PAGE_SIZE)
      @page_size = page_size.to_i
      raise ArgumentError, "The page size must be a positive Integer" unless @page_size > 0
      @pages = {}
      @lowest_known_empty_page = nil
    end

    # Returns the maximum possible byte string that can be
    # recovered from the given `io` at the given offset.
    # If the IO has been exhausted, `nil` will be returned
    # instead. Will use the cached pages where available,
    # 
    def byteslice(io, at, n_bytes)
      first_page = at / @page_size
      last_page = (at + n_bytes) / @page_size
      local_offset_on_first_page = at % @page_size

      relevant_pages = (first_page..last_page).map{|i| hydrate_page(io, i) }

      slab = relevant_pages.join
      slice = slab.byteslice(local_offset_on_first_page, n_bytes)

      if slice && !slice.empty?
        slice
      else
        nil
      end
    end

    def clear
      @pages.clear
    end

    def hydrate_page(io, page_i)
      # Avoid trying to read the page if we know there is no content to fill it
      # in the underlying IO
      if @lowest_known_empty_page && page_i >= @lowest_known_empty_page
        return nil
      end

      @pages[page_i] ||= begin
        io.seek(page_i * @page_size)
        read_result = io.read(@page_size)

        if read_result.nil?
          if @lowest_known_empty_page.nil? || @lowest_known_empty_page > page_i
            @lowest_known_empty_page = page_i
          end
        end

        read_result
      end
    end
  end
end
