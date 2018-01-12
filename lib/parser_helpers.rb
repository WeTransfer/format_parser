module FormatParser
  module ParserHelpers

    def any_format?(asked_formats)
      (asked_formats & self.formats).size > 0
    end

    def any_nature?(asked_natures)
      (asked_natures & self.natures).size > 0
    end
  end
end
