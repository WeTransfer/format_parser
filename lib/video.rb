module FormatParser
  class Video
    include FormatParser::AttributesJSON

    NATURE = :video

    attr_accessor :width_px

    attr_accessor :height_px

    attr_accessor :frame_rate

    # Type of the file (e.g :mp3)
    attr_accessor :format

    attr_accessor :codecs

    # Duration of the media object (be it audio or video) in seconds,
    # as a Float
    attr_accessor :media_duration_seconds

    # Duration of the media object in addressable frames or samples,
    # as an Integer
    attr_accessor :media_duration_frames

    # If a parser wants to provide any extra information to the caller
    # it can be placed here
    attr_accessor :intrinsics

    # The MIME type of the video
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
