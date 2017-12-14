require 'dry-validation'

module FormatParser
  class FileInformation
    class ParsingError < RuntimeError
    end

    VALID_FILE_NATURES = [:image]
    SCHEMA = Dry::Validation.Schema do
      required(:file_nature).filled(included_in?: VALID_FILE_NATURES)
      required(:file_type).filled
      optional(:width_px).filled(:int?) # and > 0
      optional(:height_px).filled(:int?) # and > 0
      optional(:has_multiple_frames).filled(:bool?)
      optional(:image_orientation).filled(:int?)
    end

    # What kind of file is it?
    attr_accessor :file_nature

    # What filetype was recognized? Will contain a non-ambiguous symbol
    # referring to the file format. The symbol can be used as a filename
    # extension safely
    attr_accessor :file_type

    # Number of pixels horizontally in the pixel buffer
    attr_accessor :width_px

    # Number of pixels vertically in the pixel buffer
    attr_accessor :height_px

    # Whether the file has multiple frames (relevant for image files and video)
    attr_accessor :has_multiple_frames

    # The angle by which the camera was rotated when taking the picture
    # (affects display width and height)
    attr_accessor :exif_orientation_angle

    # Whether the image has transparency (or an alpha channel)
    attr_accessor :has_transparency

    # Basic information about the color mode
    attr_accessor :color_mode

    # If the file has animation or is video, this might
    # indicate the number of frames. Some formats do not
    # allow retrieving this value without parsing the entire
    # file, so for GIF this might be nil even though it is
    # animated. For a boolean check, `has_multiple_frames`
    # might offer a better clue.
    attr_accessor :num_animation_or_video_frames

    # Orientation from EXIF data. Will come through as an integer.
    # To be perfectly honest EXIF orientation handling is a bit of a mess,
    # here's a reasonable blog post about it:
    # http://magnushoff.com/jpeg-orientation.html
    attr_accessor :image_orientation

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      result = SCHEMA.call(**attributes)
      if result.success?
        attributes = result.to_h
        attributes.map { |(k, v)| public_send("#{k}=", v) }
      else
        raise ParsingError, "Parsing failed with error: #{result.errors}"
      end
    end

    def self.image(**kwargs)
      new(file_nature: :image, **kwargs)
    end
  end
end
