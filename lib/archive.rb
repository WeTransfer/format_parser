require 'ks'

module FormatParser
  class Archive
    include FormatParser::AttributesJSON
    Entry = Ks.strict(:type, :size, :filename)
    NATURE = :archive

    # What filetype was recognized? Will contain a non-ambiguous symbol
    # referring to the file format. The symbol can be used as a filename
    # extension safely
    attr_accessor :format

    # Array of Entry structs
    attr_accessor :entries

    # If a parser wants to provide any extra information to the caller
    # it can be placed here
    attr_accessor :intrinsics

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
    end

    def nature
      NATURE
    end
  end
end
