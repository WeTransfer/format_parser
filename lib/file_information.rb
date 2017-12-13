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
        # What kind of file is it?
        required(:file_nature).filled(included_in?: VALID_FILE_NATURES)
        # What filetype was recognized? Will contain a non-ambiguous symbol
        # referring to the file format. The symbol can be used as a filename
        # extension safely
        required(:file_type).filled(included_in?: SUPPORTED_FILE_TYPES)
        # Number of pixels horizontally in the pixel buffer
        optional(:width_px).filled(:int?)
        # Number of pixels vertically in the pixel buffer
        optional(:height_px).filled(:int?)
        # Whether the file has multiple frames (relevant for image files and video)
        optional(:has_multiple_frames).filled(:bool?)
        # Image orientation value from EXIF. Can be between 1-9.
        # Some guidlines for using this number can be found here
        # https://beradrian.wordpress.com/2008/11/14/rotate-exif-images/
        optional(:image_orientation).filled(:int?)
      end

      result = schema.call(**attributes)
      if result.success?
        result.to_h
      else
        raise ParsingError, "Parsing failed with error: #{result.errors}"
      end
    end

    def self.image(**attributes)
      validate_and_return(file_nature: :image, **attributes)
    end

  end
end
