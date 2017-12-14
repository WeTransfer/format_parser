require 'dry-validation'

module FormatParser

  class ParsingError < StandardError; end

  class FileInformation
    VALID_FILE_NATURES = [:image]
    SUPPORTED_FILE_TYPES = [
      :jpg, :gif, :png, :psd, :dpx, :tif
    ]
    # Will only allow the attributes we specify, but since not all filetypes
    # will use all attributes, we can set them to a default value and it will
    # ignore them.

    def self.validate_and_return(**attributes)
      schema = Dry::Validation.Schema do
        required(:file_nature).filled(included_in?: VALID_FILE_NATURES)
        required(:file_type).filled(included_in?: SUPPORTED_FILE_TYPES)
        optional(:width_px).filled(:int?)
        optional(:height_px).filled(:int?)
        optional(:has_multiple_frames).filled(:bool?)
      end

      result = schema.call(**attributes)
      if result.success?
        result.to_h
      else
        raise ParsingError, "Parsing failed with error: #{result.errors}"
      end
    end
    # # What kind of file is it?
    # attribute :file_nature, Types::Strict::Symbol
    #
    # # What filetype was recognized? Will contain a non-ambiguous symbol
    # # referring to the file format. The symbol can be used as a filename
    # # extension safely
    # attribute :file_type, Types::Strict::Symbol
    #
    # # Number of pixels horizontally in the pixel buffer
    # attribute :width_px, Types::Strict::Int.default(0)
    #
    # # Number of pixels vertically in the pixel buffer
    # attribute :height_px, Types::Strict::Int.default(0)
    #
    # # Whether the file has multiple frames (relevant for image files and video)
    # attribute :has_multiple_frames, Types::Strict::Bool.default(false)
    #
    # # Image orientation value from EXIF. Can be between 1-9.
    # # Some guidlines for using this number can be found here
    # # https://beradrian.wordpress.com/2008/11/14/rotate-exif-images/
    # attribute :exif_orientation, Types::Strict::Int.optional

    def self.image(**attributes)
      validate_and_return(file_nature: :image, **attributes)
    end

  end
end
