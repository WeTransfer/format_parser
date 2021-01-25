module FormatParser
  class Text
    include FormatParser::AttributesJSON

    NATURE = :text

    attr_accessor :format
    attr_accessor :content_type

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
    end

    def nature
      NATURE
    end
  end
end
