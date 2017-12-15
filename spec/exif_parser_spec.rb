require 'spec_helper'

describe FormatParser::EXIFParser do

  describe 'is able to parse orientation for all the JPEG EXIF examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parsed = FormatParser::EXIFParser.new(File.open(jpeg_path, 'rb')).scan_jpeg
        expect(parsed).not_to be_nil

        expect(parsed.orientation.to_i).to be_kind_of(Integer)
      end
    end
  end

  describe 'is able to parse orientation for all the TIFF EXIF examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = FormatParser::EXIFParser.new(File.open(tiff_path, 'rb')).scan_tiff
        expect(parsed).not_to be_nil

        expect(parsed.orientation.to_i).to be_kind_of(Integer)
      end
    end
  end
end
