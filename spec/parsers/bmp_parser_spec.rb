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

    expect(parsed.content_type).to eq('image/bmp')

    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.intrinsics[:vertical_resolution]).to eq(2834)
    expect(parsed.intrinsics[:horizontal_resolution]).to eq(2834)
    expect(parsed.intrinsics[:data_order]).to eq(:normal)
    expect(parsed.intrinsics[:bits_per_pixel]).to eq(24)
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

    expect(parsed.content_type).to eq('image/bmp')

    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.intrinsics[:vertical_resolution]).to eq(2835)
    expect(parsed.intrinsics[:horizontal_resolution]).to eq(2835)
    expect(parsed.intrinsics[:data_order]).to eq(:inverse)
    expect(parsed.intrinsics[:bits_per_pixel]).to eq(24)
  end

  it 'parses a BMP where the pixel array location is other than 54' do
    bmp_path = fixtures_dir + '/BMP/offset_pixarray.bmp'
    parsed = subject.call(File.open(bmp_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:bmp)
    expect(parsed.color_mode).to eq(:rgb)

    expect(parsed.width_px).to eq(200)
    expect(parsed.height_px).to eq(200)

    expect(parsed.content_type).to eq('image/bmp')

    expect(parsed.intrinsics).not_to be_nil
  end

  it 'parses various BMP headers' do
    bmp_path = fixtures_dir + '/BMP/test_v5header.bmp'
    parsed = subject.call(File.open(bmp_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:bmp)
    expect(parsed.color_mode).to eq(:rgb)
    expect(parsed.width_px).to eq(40)
    expect(parsed.height_px).to eq(27)
    expect(parsed.content_type).to eq('image/bmp')
    expect(parsed.intrinsics[:bits_per_pixel]).to eq(24)
    expect(parsed.intrinsics[:data_order]).to eq(:normal)

    bmp_path = fixtures_dir + '/BMP/test_coreheader.bmp'
    parsed = subject.call(File.open(bmp_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:bmp)
    expect(parsed.color_mode).to eq(:rgb)
    expect(parsed.width_px).to eq(40)
    expect(parsed.height_px).to eq(27)
    expect(parsed.content_type).to eq('image/bmp')
    expect(parsed.intrinsics[:bits_per_pixel]).to eq(24)
    expect(parsed.intrinsics[:data_order]).to eq(:normal)
  end

  it 'refuses to parse a BMP where the pixel array location is very large' do
    junk_data = [
      'BM',
      123,
      123,
      123,
      0xFFFF
    ].pack('A2Vv2V')
    not_bmp = StringIO.new(junk_data + Random.new.bytes(1024))

    parsed = subject.call(not_bmp)

    expect(parsed).to be_nil
  end
end
