module FormatParser
  class Audio
    include FormatParser::AttributesJSON

    NATURE = :audio

    # Type of the file (e.g :mp3)
    attr_accessor :format

    # The number of audio channels for sound files that are muxed
    # and for video files with embedded sound
    attr_accessor :num_audio_channels

    # SampeThe number of audio channels for sound files that are muxed
    # and for video files with embedded sound
    attr_accessor :audio_sample_rate_hz

    # Duration of the media object (be it audio or video) in seconds,
    # as a Float
    attr_accessor :media_duration_seconds

    # Duration of the media object in addressable frames or samples,
    # as an Integer
    attr_accessor :media_duration_frames

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
