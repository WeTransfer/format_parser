module FormatParser
  class Document
    include FormatParser::AttributesJSON

    NATURE = :document

    attr_accessor :format
    attr_accessor :document_type
    attr_accessor :page_count

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
    end

    def nature
      NATURE
    end
  end
end
