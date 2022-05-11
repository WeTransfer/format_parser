require 'spec_helper'

describe FormatParser::HEIFParser do
  it 'is able to parse single heif image with heic major brand' do
    heif_path = fixtures_dir + 'HEIF/SingleImage.heic'

    result = subject.call(File.open(heif_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:image)
    expect(result.format).to eq(:heic)
    expect(result.width_px).to eq(4000)
    expect(result.height_px).to eq(3000)
    expect(result.content_type).to eq('image/heic')
    expect(result.intrinsics[:compatible_brands].should =~ ['mif1', 'heic'])
  end

  it 'is able to parse single heif image with mif1 major brand' do
    heif_path = fixtures_dir + 'HEIF/SingleImage_Autumn.heic'

    result = subject.call(File.open(heif_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:image)
    expect(result.format).to eq(:heif)
    expect(result.width_px).to eq(1440)
    expect(result.height_px).to eq(960)
    expect(result.content_type).to eq('image/heif')
    expect(result.intrinsics[:compatible_brands].should =~ ['mif1', 'heic'])
  end

  it 'is able to parse image collection with mif1 major brand' do
    heif_path = fixtures_dir + 'HEIF/ImageCollection.heic'

    result = subject.call(File.open(heif_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:image)
    expect(result.format).to eq(:heif)
    expect(result.width_px).to eq(1440)
    expect(result.height_px).to eq(960)
    expect(result.content_type).to eq('image/heif')
  end

  it 'is able to parse image collection with colour info' do
    heif_path = fixtures_dir + 'HEIF/SingleImage_Autumn_WithColourInfo.heic'

    result = subject.call(File.open(heif_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:image)
    expect(result.format).to eq(:heic)
    expect(result.width_px).to eq(1440)
    expect(result.height_px).to eq(960)
    colour_info = result.intrinsics[:colour_info]
    expect(colour_info[:colour_primaries]).to eq(28259)
    expect(colour_info[:transfer_characteristics]).to eq(27768)
    expect(colour_info[:matrix_coefficients]).to eq(2)
    expect(result.content_type).to eq('image/heic')
    expect(result.intrinsics[:compatible_brands].should =~ ['mif1', 'heic'])
  end

  it 'is able to parse image collection with pixel info' do
    heif_path = fixtures_dir + 'HEIF/SingleImage_Autumn_WithColourInfo.heic'

    result = subject.call(File.open(heif_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:image)
    expect(result.format).to eq(:heic)
    expect(result.width_px).to eq(1440)
    expect(result.height_px).to eq(960)
    pixel_info = result.intrinsics[:pixel_info]
    expect(pixel_info[0][:bits_in_channel_2]).to eq(8)
    expect(pixel_info[1][:bits_in_channel_3]).to eq(8)
    expect(pixel_info[2][:bits_in_channel_4]).to eq(8)
    expect(result.content_type).to eq('image/heic')
    expect(result.intrinsics[:compatible_brands].should =~ ['mif1', 'heic'])
  end
end
