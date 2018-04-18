require 'spec_helper'

describe FormatParser::BMPParser do
  it 'parses a BMP file with positive height_px values' do
    bmp_path = fixtures_dir + '/BMP/test.bmp'
    parsed = subject.call(File.open(bmp_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:bmp)
    expect(parsed.color_mode).to eq(:rgb)

    expect(parsed.width_px).to eq(40)
    expect(parsed.height_px).to eq(27)

    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.intrinsics[:vertical_resolution]).to eq(2834)
    expect(parsed.intrinsics[:horizontal_resolution]).to eq(2834)
    expect(parsed.intrinsics[:data_order]).to eq(:normal)
  end

  it 'parses a BMP file with negative height_px values (divergent scan order)' do
    bmp_path = fixtures_dir + '/BMP/test2.bmp'
    parsed = subject.call(File.open(bmp_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:bmp)
    expect(parsed.color_mode).to eq(:rgb)

    expect(parsed.width_px).to eq(1920)
    expect(parsed.height_px).to eq(1080)

    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.intrinsics[:vertical_resolution]).to eq(2835)
    expect(parsed.intrinsics[:horizontal_resolution]).to eq(2835)
    expect(parsed.intrinsics[:data_order]).to eq(:inverse)
  end
end
