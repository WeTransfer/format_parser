require 'spec_helper'

describe FormatParser::Parsers::Image::EXIFParser do
  # ORIENTATIONS = [
  #   :top_left,
  #   :top_right,
  #   :bottom_right,
  #   :bottom_left,
  #   :left_top,
  #   :right_top,
  #   :right_bottom,
  #   :left_bottom
  # ]

  describe 'is able to correctly parse orientation for all the JPEG EXIF examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      filename = File.basename(jpeg_path)
      it "is able to parse #{filename}" do
        parser = described_class.new(:jpeg, File.open(jpeg_path, 'rb'))
        parser.scan_image_exif
        expect(parser).not_to be_nil

        expect(parser.orientation).to be_kind_of(Symbol)
        # Filenames in this dir correspond with the orientation of the file
        expect(filename.include?(parser.orientation.to_s)).to be true
      end
    end
  end

  describe 'is able to correctly parse orientation for all the TIFF EXIF examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      filename = File.basename(tiff_path)
      it "is able to parse #{filename}" do
        parser = described_class.new(:tiff, File.open(tiff_path, 'rb'))
        parser.scan_image_exif
        expect(parser).not_to be_nil

        expect(parser.orientation).to be_kind_of(Symbol)
        # Filenames in this dir correspond with the orientation of the file
        expect(filename.include?(parser.orientation.to_s)).to be true
      end
    end
  end
end
