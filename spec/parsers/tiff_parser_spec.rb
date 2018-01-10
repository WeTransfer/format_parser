require 'spec_helper'

describe FormatParser::TIFFParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(fixtures_dir + '/TIFF/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:tif)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  describe 'is able to parse all the TIFF exif examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))
        expect(parsed).not_to be_nil

        expect(parsed.orientation).to be_kind_of(Symbol)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

end
