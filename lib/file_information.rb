module FormatParser
  class FileInformation
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
    attr_accessor :orientation

    # Only permits assignments via defined accessors
    def initialize(**kwargs)
      kwargs.map { |(k, v)| public_send("#{k}=", v) }
    end

    def self.image(**kwargs)
      new(file_nature: :image, **kwargs)
    end
  end
end
