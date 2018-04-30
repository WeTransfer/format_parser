module FormatParser
  class Image
    include FormatParser::AttributesJSON

    NATURE = :image

    # What filetype was recognized? Will contain a non-ambiguous symbol
    # referring to the file format. The symbol can be used as a filename
    # extension safely
    attr_accessor :format

    # Number of pixels horizontally in the pixel buffer
    attr_accessor :width_px

    # Number of pixels vertically in the pixel buffer
    attr_accessor :height_px

    # Image width when displayed and taking into account things like camera
    # orientation tags and non-square pixels/anamorphicity. The dimensions
    # used for display are always computed by _squashing_, not by _stretching_.
    #
    # If the display width/height are not specified, the sizes of the
    # pixel buffer will get returned instead (values of the `width_px`/`height_px`
    # attributes)
    attr_accessor :display_width_px

    # Image height when displayed and taking into account things like camera
    # orientation tags and non-square pixels/anamorphicity. The dimensions
    # used for display are always computed by _squashing_, not by _stretching_.
    #
    # If the display width/height are not specified, the sizes of the
    # pixel buffer will get returned instead (values of the `width_px`/`height_px`
    # attributes)
    attr_accessor :display_height_px

    # Whether the file has multiple frames (relevant for image files and video)
    attr_accessor :has_multiple_frames

    # The angle by which the camera was rotated when taking the picture
    # (affects display width and height)
    attr_accessor :orientation

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

    # If a parser wants to provide any extra information to the caller
    # it can be placed here
    attr_accessor :intrinsics

    # Only permits assignments via defined accessors
    def initialize(**attributes)
      attributes.map { |(k, v)| public_send("#{k}=", v) }
      @display_width_px ||= @width_px
      @display_height_px ||= @height_px
    end

    def nature
      NATURE
    end
  end
end
