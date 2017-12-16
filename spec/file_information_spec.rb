require 'spec_helper'

describe FormatParser::FileInformation do

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
