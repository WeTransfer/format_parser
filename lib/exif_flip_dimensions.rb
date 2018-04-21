module FormatParser::ExifFlipDimensions
  NORMAL_ORIENTATIONS = [:bottom_left, :bottom_right, :top_left, :top_right]

  def rotated?(exif_orientation_sym)
    NORMAL_ORIENTATIONS.include?(exif_orientation_sym) ? false : true
  end
end
