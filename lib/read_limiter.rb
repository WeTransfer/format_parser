class FormatParser::ReadLimiter
  NO_LIMIT = nil
  class BudgetExceeded < StandardError
  end

  def initialize(io, max_bytes: NO_LIMIT, max_reads: NO_LIMIT, max_seeks: NO_LIMIT)
    @max_bytes = max_bytes
    @max_reads = max_reads
    @max_seeks = max_seeks

    @io = io
    @seeks = 0
    @reads = 0
    @bytes = 0
  end

  def seek(to_offset)
    @seeks += 1
    if @max_seeks && @seeks > @max_seeks
      raise BudgetExceeded, "Seek budget exceeded (%d seeks performed)" % @max_seeks
    end
    @io.seek(to_offset)
  end

  def read(n)
    @bytes += n
    @reads += 1

    if @max_bytes && @bytes > @max_bytes
      raise BudgetExceeded, "Read bytes budget (%d) exceeded" % @max_bytes
    end

    if @max_reads && @reads > @max_reads
      raise BudgetExceeded, "Number of read() calls exceeded (%d max)" % @max_reads
    end

    @io.read(n)
  end
  
  # A particular implementation of read meant to make reading JPEG EXIF data
  # easier on remote reads, but if we want to override the defaults and 
  # use it somewhere else we can. (EXIFR expects just plain ol' readbyte so
  # we have to include the defaults)
  def readbyte(num_bytes_to_read: 1, unpack_code: "C")
    @io.read(num_bytes_to_read).unpack(unpack_code).first
  end
  
  # EXIFR requires a getbyte method that does exactly the same thing as readbyte

  def getbyte
    readbyte
  end
  
end
