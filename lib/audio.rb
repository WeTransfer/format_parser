module FormatParser
  class Audio
    include FormatParser::AttributesJSON

    NATURE = :audio

    # Title of the audio
    attr_accessor :title

    # Album of the audio
    attr_accessor :album

    # Artist of the audio
    attr_accessor :artist

    # Type of the file (e.g :mp3)
    attr_accessor :format

    # The number of audio channels for sound files that are muxed
    # and for video files with embedded sound
    attr_accessor :num_audio_channels

    # The sample rate of the audio file in hertz, as an Integer
    attr_accessor :audio_sample_rate_hz

    # Duration of the media object (be it audio or video)
    # in seconds, as a Float
    attr_accessor :media_duration_seconds

    # Duration of the media object in addressable frames or samples,
    # as an Integer
    attr_accessor :media_duration_frames

    # If a parser wants to provide any extra information to the caller
    # it can be placed here
    attr_accessor :intrinsics

    # The MIME type of the sound file
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
