class FormatParser::ReadLimiter
  NO_LIMIT = :nolimit
  
  def initialize(io, max_bytes: NO_LIMIT, max_reads: NO_LIMIT, max_seeks: NO_LIMIT)
    @io = io
    @seeks = 0
    @reads = 0
    @bytes = 0
  end

  def seek(to_offset)
    @seeks += 1
    raise "Seek budget exceeded" if @seeks > max_seeks
    @io.seek(to_offset)
  end
  
  def read(n)
    @bytes += n
    @reads += 1
    raise "Read bytes budget exceeded" if @bytes > max_bytes
    raise "Number of read() calls exceeded" if @bytes > max_bytes
    @io.read(n)
  end
end

