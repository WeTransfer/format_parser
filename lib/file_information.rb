require 'dry-types'
require 'dry-struct'

module FormatParser

  module Types
    include Dry::Types.module
  end

  class FileInformation < Dry::Struct
    # What kind of file is it?
    attribute :file_nature, Types::Strict::String

    # What filetype was recognized? Will contain a non-ambiguous symbol
    # referring to the file format. The symbol can be used as a filename
    # extension safely
    attribute :file_type, Types::Strict::Symbol

    # Number of pixels horizontally in the pixel buffer
    attribute :width_px, Types::Strict::Int.optional

    # Number of pixels vertically in the pixel buffer
    attribute :height_px, Types::Strict::Int.optional

    # Whether the file has multiple frames (relevant for image files and video)
    attribute :has_multiple_frames, Types::Strict::Bool.optional

    # Image orientation value from EXIF. Can be between 1-9.
    # Some guidlines for using this number can be found here
    # https://beradrian.wordpress.com/2008/11/14/rotate-exif-images/
    attribute :exif_orientation, Types::Strict::Int.optional

  end
end
