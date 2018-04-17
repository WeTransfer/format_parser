require 'spec_helper'

describe FormatParser::BMPParser do
  describe 'is able to parse BMP files' do
    context 'with positive height_px values' do
      it 'parses a BMP file' do
        bmp_path = fixtures_dir + '/BMP/test.bmp'
        parsed = subject.call(File.open(bmp_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:bmp)
        expect(parsed.color_mode).to eq(:rgb)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0
        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0

        expect(parsed.intrinsics).not_to be_nil
        expect(parsed.intrinsics[:vertical_resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:horizontal_resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:data_order]).to eq(:normal)
      end
    end

    context 'with negative height_px values' do
      it 'parses a BMP file' do
        bmp_path = fixtures_dir + '/BMP/test2.bmp'
        parsed = subject.call(File.open(bmp_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:bmp)
        expect(parsed.color_mode).to eq(:rgb)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0
        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0

        expect(parsed.intrinsics).not_to be_nil
        expect(parsed.intrinsics[:vertical_resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:horizontal_resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:data_order]).to eq(:inverse)
      end
    end
  end
end
