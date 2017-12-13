require 'spec_helper'

describe FormatParser::FileInformation do

  let(:valid_file_natures) {[:image]}
  let(:supported_file_types) {[:jpg, :gif, :png, :psd, :dpx, :tif]}

  it 'succeeds with supported file natures' do
    valid_file_natures.each do |file_nature|
      result = described_class.validate_and_return(file_nature: file_nature, file_type: :jpg)
      expect(result[:file_nature]).to eq(file_nature)
    end
  end

  it 'succeeds with supported file_types' do
    supported_file_types.each do |file_type|
      result = described_class.validate_and_return(file_nature: :image, file_type: file_type)
      expect(result[:file_type]).to eq(file_type)
    end
  end

  it 'raises on an unsupported file_nature' do
    expect{
      described_class.validate_and_return(file_nature: :coffee, file_type: :jpg)
    }.to raise_error(/file_nature=>/)
  end

  it 'raises on an unsupported file_type' do
    expect{
      described_class.validate_and_return(file_nature: :image, file_type: :exe)
    }.to raise_error(/file_type=>/)
  end

  it 'succeds with a width_px that is an integer' do
    result = described_class.validate_and_return(file_nature: :image, file_type: :jpg, width_px: 10_000)
    expect(result[:width_px]).to eq(10_000)
  end

  it 'succeds with a height_px that is an integer' do
    result = described_class.validate_and_return(file_nature: :image, file_type: :jpg, height_px: 10_000)
    expect(result[:height_px]).to eq(10_000)
  end

  it 'succeds with a has_multiple_frames that is a boolean' do
    result = described_class.validate_and_return(file_nature: :image, file_type: :jpg, has_multiple_frames: true)
    expect(result[:has_multiple_frames]).to eq(true)
  end

  it 'succeds with a image_orientation that is an integer' do
    result = described_class.validate_and_return(file_nature: :image, file_type: :jpg, image_orientation: 1)
    expect(result[:image_orientation]).to eq(1)
  end
end
