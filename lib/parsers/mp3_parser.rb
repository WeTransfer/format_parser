require 'mp3file'

class FormatParser::MP3Parser
  
  class FakePathname
    def initialize(with_remote_io)
      @io = with_remote_io
    end

    def seek(to, mode=IO::SEEK_SET)
      case mode
      when IO::SEEK_SET
        @io.seek(to)
      when IO::SEEK_END
        @io.seek(@io.size + to)
      when IO::SEEK_CUR
        @io.seek(@io.pos + to)
      end
    end

    def close
      # Do nothing
    end

    def tell
      @io.pos
    end

    def read(n)
      @io.read(n)
    end

    def eof?
      @io.pos >= @io.size
    end

    # Internally Mp3file calls "open" thinking this is a Pathname object.
    # We just return self, because such are the ways of evil.
    def open(mode)
      self
    end
  end

  def information_from_io(io)
    cio = FormatParser::IOConstraint.new(io)
    
    # we have to reuse our ReadLimiter once more. The parser
    # in Mp3file is not written by us, and fuzzing shows it can
    # be derailed into an endless loop of seek+read, which we have to
    # prevent here explicitly
    lim = FormatParser::ReadLimiter.new(cio, max_reads: 512, max_seeks: 512)
    adapter = FakePathname.new(lim)

    file_info = Mp3file::MP3File.new(adapter)
  rescue Mp3file::InvalidMP3FileError
    nil
  end

  FormatParser.register_parser_constructor self
end
