require 'spec_helper'

describe FormatParser::EXIFParser do

  describe 'is able to parse orientation for all the JPEG EXIF examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parser = FormatParser::EXIFParser.new(:jpeg, File.open(jpeg_path, 'rb'))
        parser.scan_image_exif
        expect(parser).not_to be_nil

        expect(parser.orientation).to be_kind_of(Symbol)
      end
    end
  end

  describe 'is able to parse orientation for all the TIFF EXIF examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parser = FormatParser::EXIFParser.new(:tiff, File.open(tiff_path, 'rb'))
        parser.scan_image_exif
        expect(parser).not_to be_nil

        expect(parser.orientation).to be_kind_of(Symbol)
      end
    end
  end
end
