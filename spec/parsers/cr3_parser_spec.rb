require 'spec_helper'

describe FormatParser::CR3Parser do
  Dir.glob(fixtures_dir + '/CR3/*.cr3').sort.each do |file_path|
    it "is able to parse #{File.basename(file_path)}" do
      result = subject.call(File.open(file_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:image)
      expect(result.width_px).to be > 0
      expect(result.height_px).to be > 0
      expect(result.content_type).to eq('image/x-canon-cr3')
      expect(result.intrinsics).not_to be_nil
    end
  end

  it 'parses a CR3 file and provides the necessary metadata' do
    file_path = fixtures_dir + '/CR3/Canon EOS R10 (RAW).CR3'

    result = subject.call(File.open(file_path, 'rb'))
    expect(result.nature).to eq(:image)
    expect(result.width_px).to eq(6000)
    expect(result.height_px).to eq(4000)
    expect(result.orientation).to eq(:top_left)
    expect(result.display_width_px).to eq(6000)
    expect(result.display_height_px).to eq(4000)
    expect(result.content_type).to eq('image/x-canon-cr3')
    expect(result.intrinsics).not_to be_nil
    expect(result.intrinsics[:atom_tree]).not_to be_nil
    expect(result.intrinsics[:exif]).not_to be_nil
    expect(result.intrinsics[:exif][:image_length]).to eq(result.height_px)
    expect(result.intrinsics[:exif][:image_width]).to eq(result.width_px)
  end
end
