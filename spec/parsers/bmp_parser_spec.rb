require 'spec_helper'

describe FormatParser::BMPParser do
  describe 'is able to parse all the examples of BMP' do
    Dir.glob(fixtures_dir + '/*.bmp').each do |bmp_path|
      it "is able to parse #{File.basename(bmp_path)}" do
        parsed = subject.call(File.open(bmp_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:bmp)
        expect(parsed.color_mode).to eq(:rgb)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be_kind_of(Integer)

        expect(parsed.intrinsics).not_to be_nil
        expect(parsed.intrinsics[:vertical_resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:horizontal_resolution]).to be_kind_of(Integer)
      end
    end
  end
end
