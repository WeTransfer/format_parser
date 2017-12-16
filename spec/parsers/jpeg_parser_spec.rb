require 'spec_helper'

describe FormatParser::JPEGParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(fixtures_dir + '/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parsed = subject.information_from_io(File.open(jpeg_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.file_nature).to eq(:image)
        expect(parsed.file_type).to eq(:jpg)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  describe 'is able to parse all the JPEG exif examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parsed = subject.information_from_io(File.open(jpeg_path, 'rb'))
        expect(parsed).not_to be_nil

        expect(parsed.orientation).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

end
