require 'spec_helper'

describe FormatParser::FileInformation do

  let(:valid_file_natures) {[:image]}
  let(:supported_file_types) {[:jpg, :gif, :png, :psd, :dpx, :tif]}

  context "Schema checks" do
    it 'succeeds with supported file natures' do
      valid_file_natures.each do |file_nature|
        result = described_class.new(file_nature: file_nature, file_type: :jpg)
        expect(result.file_nature).to eq(file_nature)
      end
    end

    it 'raises on an unsupported file_nature' do
      expect{
        described_class.new(file_nature: :coffee, file_type: :jpg)
      }.to raise_error(/file_nature=>/)
    end

    it 'succeeds with a width_px that is an integer' do
      result = described_class.new(file_nature: :image, file_type: :jpg, width_px: 10_000)
      expect(result.width_px).to eq(10_000)
    end

    it 'succeeds with a height_px that is an integer' do
      result = described_class.new(file_nature: :image, file_type: :jpg, height_px: 10_000)
      expect(result.height_px).to eq(10_000)
    end

    it 'succeeds with a has_multiple_frames that is a boolean' do
      result = described_class.new(file_nature: :image, file_type: :jpg, has_multiple_frames: true)
      expect(result.has_multiple_frames).to eq(true)
    end

    it 'succeeds with a image_orientation that is an integer' do
      result = described_class.new(file_nature: :image, file_type: :jpg, image_orientation: 1)
      expect(result.image_orientation).to eq(1)
    end

    it 'raises when width_px is not an integer' do
      expect{
        described_class.new(file_nature: :image, file_type: :jpg, width_px: 4.8)
      }.to raise_error(/width_px=>/)
    end

    it 'raises when height_px is not an integer' do
      expect{
        described_class.new(file_nature: :image, file_type: :jpg, height_px: 1.5)
      }.to raise_error(/height_px=>/)
    end

    it 'raises when has_multiple_frames is not a boolean' do
      expect{
        described_class.new(file_nature: :image, file_type: :jpg, has_multiple_frames: 1.6)
      }.to raise_error(/has_multiple_frames=>/)
    end

    it 'raises when image_orientation is not an integer' do
      expect{
        described_class.new(file_nature: :image, file_type: :jpg, image_orientation: 2.3)
      }.to raise_error(/image_orientation=>/)
    end
  end

  context "File data checks" do
    it 'succeeds with relevant attributes' do
      result = described_class.new(file_nature: :image, file_type: :jpg, width_px: 42, height_px: 10, image_orientation: 1)
      expect(result.file_nature).to eq(:image)
      expect(result.file_type).to eq(:jpg)
      expect(result.width_px).to eq(42)
      expect(result.height_px).to eq(10)
      expect(result.image_orientation).to eq(1)
    end
  end

end
