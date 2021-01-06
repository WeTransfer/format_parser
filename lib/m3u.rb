module FormatParser
  class M3U
    include FormatParser::AttributesJSON

    NATURE = :text

    attr_accessor :format
    attr_accessor :size

    # Contains all the file content
    attr_accessor :content

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
    end

    def nature
      NATURE
    end
  end
end
