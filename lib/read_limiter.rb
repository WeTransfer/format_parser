# Is used to limit the number of reads/seeks parsers can perform
class FormatParser::ReadLimiter
  NO_LIMIT = nil

  attr_reader :seeks, :reads, :bytes

  class BudgetExceeded < StandardError
  end

  # Creates a ReadLimiter wrapper around the given IO object and sets the limits
  # on the number of reads/writes
  #
  # @param io[#seek, #pos, #size, #read] the IO object to wrap
  # @param max_bytes[Integer, nil] how many bytes can we read from this before an exception is raised
  # @param max_reads[Integer, nil] how many read() calls can we perform on this before an exception is raised
  # @param max_seeks[Integer, nil] how many seek() calls can we perform on this before an exception is raised
  def initialize(io, max_bytes: NO_LIMIT, max_reads: NO_LIMIT, max_seeks: NO_LIMIT)
    @max_bytes = max_bytes
    @max_reads = max_reads
    @max_seeks = max_seeks

    @io = io
    @seeks = 0
    @reads = 0
    @bytes = 0
  end

  # Returns the size of the resource contained in the IO
  #
  # @return Integer
  def size
    @io.size
  end

  # Returns the current position/offset within the IO
  #
  # @return Integer
  def pos
    @io.pos
  end

  # Seeks the IO to the given absolute offset from the start of the file/resource
  #
  # @param to[Integer] offset in the IO
  # @return Integer
  def seek(to)
    @seeks += 1
    if @max_seeks && @seeks > @max_seeks
      raise BudgetExceeded, 'Seek budget exceeded (%d seeks performed)' % @max_seeks
    end
    @io.seek(to)
  end

  # Returns at most `n_bytes` of data from the IO or less if less data was available
  # before the EOF was hit
  #
  # @param n_bytes[Integer]
  # @return [String, nil] the content read from the IO or `nil` if no data was available
  def read(n_bytes)
    @bytes += n_bytes
    @reads += 1

    if @max_bytes && @bytes > @max_bytes
      raise BudgetExceeded, 'Read bytes budget (%d) exceeded' % @max_bytes
    end

    if @max_reads && @reads > @max_reads
      raise BudgetExceeded, 'Number of read() calls exceeded (%d max)' % @max_reads
    end

    @io.read(n_bytes)
  end

  # Sends the metrics about the state of this ReadLimiter to a Measurometer
  #
  # @param prefix[String] the prefix to set. For example, with prefix "TIFF" the metrics will be called
  #   `format_parser.TIFF.read_limiter.num_seeks` and so forth
  # @return void
  def send_metrics(prefix)
    Measurometer.add_distribution_value('format_parser.%s.read_limiter.num_seeks' % prefix, @seeks)
    Measurometer.add_distribution_value('format_parser.%s.read_limiter.num_reads' % prefix, @reads)
    Measurometer.add_distribution_value('format_parser.%s.read_limiter.read_bytes' % prefix, @bytes)
  end

  # Resets all the recorded call counters so that the object can be reused for the next parser,
  # which will have it's own limits
  # @return void
  def reset_limits!
    @seeks = 0
    @reads = 0
    @bytes = 0
  end
end
