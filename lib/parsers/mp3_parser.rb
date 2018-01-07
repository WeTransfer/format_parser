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

    def open(mode)
      self
    end
  end

  def information_from_io(io)
    adapter = FakePathname.new(io)
    file_info = Mp3file::MP3File.new(adapter)
    raise file_info.inspect
  end

  FormatParser.register_parser_constructor self
end
