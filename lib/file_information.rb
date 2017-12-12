module FormatParser
  class FileInformation
    # Number of pixels horizontally in the pixel buffer
    attr_accessor :width_px

    # Number of pixels vertically in the pixel buffer
    attr_accessor :height_px

    # Whether the file has multiple frames (relevant for image files and video)
    attr_accessor :has_multiple_frames

    # Only permits assignments via defined accessors
    def initialize(**kwargs)
      kwargs.map { |(k, v)| public_send("#{k}=", v) }
    end
  end
end
