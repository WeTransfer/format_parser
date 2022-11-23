module FormatParser
  class Archive
    include FormatParser::AttributesJSON

    class Entry < Struct.new(:type, :size, :filename, keyword_init: true)
      def to_json(*a)
        to_h.to_json(*a)
      end
    end

    # Lots of Office and LibreOffice documents are in fact packaged into
    # ZIPs, as are .epub files. We make `nature` customisable for this occasion
    attr_accessor :nature

    # What filetype was recognized? Will contain a non-ambiguous symbol
    # referring to the file format. The symbol can be used as a filename
    # extension safely
    attr_accessor :format

    # Array of Entry structs
    attr_accessor :entries

    # If a parser wants to provide any extra information to the caller
    # it can be placed here
    attr_accessor :intrinsics

    # The MIME type of the archive
    attr_accessor :content_type

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
    end
  end
end
