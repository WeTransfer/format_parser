require 'spec_helper'

describe FormatParser::JPEGParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(fixtures_dir + '/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parsed = subject.call(File.open(jpeg_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:jpg)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  it 'is able to parse JPEG examples with EXIF tags containing different orientations from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      parsed = subject.call(File.open(jpeg_path, 'rb'))
      expect(parsed).not_to be_nil

      expect(parsed.orientation).to be_kind_of(Symbol)
      expect(parsed.width_px).to be > 0
      expect(parsed.height_px).to be > 0
    end

    bottom_left_path = fixtures_dir + '/exif-orientation-testimages/jpg/bottom_left.jpg'
    parsed = subject.call(File.open(bottom_left_path, 'rb'))
    expect(parsed.orientation).to eq(:bottom_left)
    expect(parsed.width_px).to eq(1240)
    expect(parsed.height_px).to eq(1754)

    top_right_path = fixtures_dir + '/exif-orientation-testimages/jpg/right_bottom.jpg'
    parsed = subject.call(File.open(top_right_path, 'rb'))
    expect(parsed.orientation).to eq(:right_bottom)
    expect(parsed.width_px).to eq(1754)
    expect(parsed.height_px).to eq(1240)
  end

  it 'gives true pixel dimensions priority over pixel dimensions in EXIF tags' do
    jpeg_path = fixtures_dir + '/JPEG/divergent_pixel_dimensions_exif.jpg'
    result = subject.call(File.open(jpeg_path, 'rb'))
    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1280)
    expect(result.intrinsics).to eq(exif_pixel_x_dimension: 8214, exif_pixel_y_dimension: 5476)
  end
end
