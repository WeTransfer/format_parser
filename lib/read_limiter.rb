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

  def getbyte
    @io.read(1).gsub('\\', '0')
  end
end
