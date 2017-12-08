require 'ks'

module FormatParser
  FileInformation = Ks.strict(:width_px, :height_px)

  module IOUtils
    def safe_read(io, n)
      buf = io.read(n)

      if !buf
        raise "We wanted to read #{n} bytes from the IO, but the IO is at EOF"
      end

      if buf.bytesize != n
        raise "We wanted to read #{n} bytes from the IO, but we got #{buf.bytesize} instead"
      end

      $stderr.puts buf.inspect

      buf
    end
  end

  class PNGParser
    PNG_HEADER_BYTES = [137, 80, 78, 71, 13, 10, 26, 10]
    include IOUtils

    def information_from_io(io)
      io.seek(0)
      magic_bytes = safe_read(io, 8).unpack("C8")

      return unless magic_bytes == PNG_HEADER_BYTES

      # This is mostly likely a PNG, so let's read some chunks
      loop do
        chunk_length = safe_read(io, 4).unpack("N").first
        chunk_type = safe_read(io, 4)
        if chunk_type == "IHDR"
          chunk_data = safe_read(io, chunk_length)
          # Width:              4 bytes
          # Height:             4 bytes
          # Bit depth:          1 byte
          # Color type:         1 byte (0, 2, 3, 4, 6)
          # Compression method: 1 byte
          # Filter method:      1 byte
          # Interlace method:   1 byte
          w, h, depth, color_type, compression, filter, interlace = chunk_data.unpack("N2C5")
          return FileInformation.new(width_px: w, height_px: h)
        end
      end
    end
  end

  class JPEGParser
    include IOUtils
    
    # SOI	0xFF, 0xD8	none	Start Of Image	
    # SOF0	0xFF, 0xC0	variable size	Start Of Frame (baseline DCT)	Indicates that this is a baseline DCT-based JPEG, and specifies the width, height, number of components, and component subsampling (e.g., 4:2:0).
    # SOF2	0xFF, 0xC2	variable size	Start Of Frame (progressive DCT)	Indicates that this is a progressive DCT-based JPEG, and specifies the width, height, number of components, and component subsampling (e.g., 4:2:0).
    # DHT	0xFF, 0xC4	variable size	Define Huffman Table(s)	Specifies one or more Huffman tables.
    # DQT	0xFF, 0xDB	variable size	Define Quantization Table(s)	Specifies one or more quantization tables.
    # DRI	0xFF, 0xDD	4 bytes	Define Restart Interval	Specifies the interval between RSTn markers, in Minimum Coded Units (MCUs). This marker is followed by two bytes indicating the fixed size so it can be treated like any other variable size segment.
    # SOS	0xFF, 0xDA	variable size	Start Of Scan	Begins a top-to-bottom scan of the image. In baseline DCT JPEG images, there is generally a single scan. Progressive DCT JPEG images usually contain multiple scans. This marker specifies which slice of data it will contain, and is immediately followed by entropy-coded data.
    # RSTn	0xFF, 0xDn (n=0..7)	none	Restart	Inserted every r macroblocks, where r is the restart interval set by a DRI marker. Not used if there was no DRI marker. The low three bits of the marker code cycle in value from 0 to 7.
    # APPn	0xFF, 0xEn	variable size	Application-specific	For example, an Exif JPEG file uses an APP1 marker to store metadata, laid out in a structure based closely on TIFF.
    # COM	0xFF, 0xFE	variable size	Comment	Contains a text comment.
    # EOI	0xFF, 0xD9	none	End Of Image	

    class MatchedMarker < Struct.new(:offset, :short_name, :marker_bytes, :marker_length_including_header)
    end

    class Marker
      include IOUtils
      def match_and_skip_to_next(io)
        matched_at = io.pos
        two_bytes = safe_read(io, 2)
        if @byte_patterns.include?(two_bytes)
          marker_length = @variable ? safe_read(io, 2).unpack("n").first : @fixed
          io.seek(matched_at + two_bytes.bytesize + marker_length)
          return MatchedMarker.new(matched_at, @short_name, two_bytes, 2 + marker_length)
        else
          io.seek(matched_at)
          nil
        end
      end
    end

    class Skip
      include IOUtils
      def match_and_skip_to_next(io)
        safe_read(io, 2)
        nil
      end
    end

    class FixedSizeMarker < Marker
      def initialize(short_name, one_or_multiple_headers, segment_length)
        one_or_multiple_headers = [one_or_multiple_headers] unless one_or_multiple_headers.is_a?(Array)
        @short_name = short_name
        @byte_patterns = one_or_multiple_headers
        @fixed = segment_length
      end
    end

    class VariableSizeMarker < Marker
      def initialize(short_name, one_or_multiple_headers)
        one_or_multiple_headers = [one_or_multiple_headers] unless one_or_multiple_headers.is_a?(Array)
        @short_name = short_name
        @byte_patterns = one_or_multiple_headers
        @bytes = one_or_multiple_headers
        @variable = true
      end
    end

    POSSIBLE_MARKERS = [
      FixedSizeMarker.new(:SOI, "\xFF\xD8".b, 0),     # SOI
      VariableSizeMarker.new(:SOF0, "\xFF\xC0".b),     # SOF0
      VariableSizeMarker.new(:SOF2, "\xFF\xC2".b),     # SOF2
      VariableSizeMarker.new(:DHT, "\xFF\xC4".b),     # DHT
      VariableSizeMarker.new(:DQT, "\xFF\xDB".b),     # DQT
      # DRI - Specifies the interval between RSTn markers, in Minimum Coded Units (MCUs).
      # This marker is followed by two bytes indicating the fixed size so it can be treated like any other variable size segment.
      FixedSizeMarker.new(:SOS, "\xFF\xDD".b, 4),     # SOS
      FixedSizeMarker.new(:RSTn, (208..215).map{|lb| [255, lb].pack("C2") }, 0),  #RSTn (where n == 0..7)
      VariableSizeMarker.new(:APPn,  (224..239).map{|lb| [255, lb].pack("C2") }), # For example, an Exif JPEG file uses an APP1 marker to store metadata, laid out in a structure based closely on TIFF.
      VariableSizeMarker.new(:COM, "\xFF\xFE".b),     # COM
      FixedSizeMarker.new(:EOI, "\xFF\xD9".b, 0),     # EOI
      Skip.new,
    ]

    def information_from_io(io)
      io.seek(0)
      return unless safe_read(io, 2) == "\xFF\xD8".b

      io.seek(0)
      loop do
        POSSIBLE_MARKERS.each do |marker_definition|
          if matched = marker_definition.match_and_skip_to_next(io)
            $stderr.puts matched.inspect
          end
        end
      end

      raise "Poo!"
    end
  end

  class JPEGParser2
    def information_from_io(io)
      d = JPEGScanner.new(io)
      d.scan
    end

    class JPEGScanner
      include IOUtils
      SOF_MARKERS = [0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF]
      EOI_MARKER  = 0xD9  # end of image
      SOS_MARKER  = 0xDA  # start of stream
      APP1_MARKER = 0xE1  # maybe EXIF

      attr_reader :width, :height, :angle

      def initialize(io)
        @buf = io
        @buf.seek(0)
        @width  = nil
        @height = nil
        @angle  = 0
      end

      def advance(n)
        safe_read(@buf, n); nil
      end

      def read_char
        safe_read(@buf, 1).unpack('C').first
      end

      def read_short
        safe_read(@buf, 2).unpack('n*').first
      end

      def scan
        advance(2)

        while marker = read_next_marker
          case marker
          when *SOF_MARKERS
            $stderr.puts "SOF"
            scan_start_of_frame
          when EOI_MARKER, SOS_MARKER
            $stderr.puts "SOS, EOI"
            break
#            when APP1_MARKER
#              scan_app1_frame
          else
            skip_frame
          end
        end

        width && height
      end

      # Read a byte, if it is 0xFF then skip bytes as long as they are also 0xFF (byte stuffing)
      # and return the first byte scanned that is not 0xFF
      def read_next_marker
        c = read_char while c != 0xFF
        c = read_char while c == 0xFF
        c
      end

      def scan_start_of_frame
        length = read_short
        read_char # depth, unused
        height = read_short
        width  = read_short
        size   = read_char

        if length == (size * 3) + 8
          @width, @height = width, height
        else
          raise_scan_error
        end
      end

      def scan_app1_frame
        frame = read_frame
        if frame[0..5] == "Exif\000\000"
          scanner = ExifScanner.new(frame[6..-1])
          if scanner.scan
            case scanner.orientation
            when :bottom_right
              @angle = 180
            when :left_top, :right_top
              @angle = 90
            when :right_bottom, :left_bottom
              @angle = 270
            end
          end
        end
      rescue ExifScanner::ScanError
      end

      def read_frame
        length = read_short - 2
        read_data(length)
      end

      def skip_frame
        length = read_short - 2
        advance(length)
      end
    end
  end

  
  def self.parse(io) # #seek(n_bytes, IO::SEEK_SET), #read(n_bytes_or_nil)
    parsers = [PNGParser]
    parsers.each do |parser|
      if info = parser.information_from_io(io)
        return info
      end
    end
  
    raise "No parser could parse #{io.inspect}"
  end
end

if __FILE__ == $0
#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test.png', 'rb')
#  file_info = FormatParser::PNGParser.new.information_from_io(fi)
#  $stderr.puts file_info.inspect


  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test4.jpg', 'rb')
  file_info = FormatParser::JPEGParser2.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test1.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test2.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)

#  fi = File.open('/Users/julik/Code/we/fastimage/test/fixtures/test3.jpg', 'rb')
#  file_info = FormatParser::JPEGParser.new.information_from_io(fi)
end