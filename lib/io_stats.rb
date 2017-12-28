require 'delegate'

class FormatParser::IOStats < SimpleDelegator
  def seek(*)
    @seek_calls ||= 0
    super.tap {
      @seek_calls += 1
    }
  end

  def read(*)
    @read_calls ||= 0
    @read_bytes ||= 0

    @read_calls += 1
    super.tap { |r|
      @read_bytes += r.bytesize if r
    }
  end
  
  def stats
    {read_bytes: @read_bytes.to_i, num_reads: @read_calls.to_i, num_seeks: @seek_calls.to_i}
  end
end
