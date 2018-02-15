require 'spec_helper'

describe FormatParser::CR2Parser do
  describe 'is able to parse CR2 files' do
    Dir.glob(fixtures_dir + '/CR2/*.CR2').each do |cr2_path|
      it "is able to parse #{File.basename(cr2_path)}" do
        parsed = subject.call(File.open(cr2_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:cr2)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0

        expect(parsed.intrinsics).not_to be_nil
        expect(parsed.intrinsics[:camera_model]).to be_kind_of(String)
        expect(parsed.intrinsics[:camera_model]).to match(/Canon \w+/)
        expect(parsed.intrinsics[:shoot_date]).to be_kind_of(String)
        expect(parsed.intrinsics[:shoot_date]).to match(/\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2}/)
        expect(parsed.intrinsics[:exposure]).to be_kind_of(String)
        expect(parsed.intrinsics[:exposure]).to match(/1\/[0-9]+/)
        expect(parsed.intrinsics[:aperture]).to be_kind_of(String)
        expect(parsed.intrinsics[:aperture]).to match(/f[0-9]+\.[0-9]/)
        expect(parsed.intrinsics[:resolution]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:resolution]).to be > 0
        expect(parsed.intrinsics[:preview_offset]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:preview_offset]).to be > 0
        expect(parsed.intrinsics[:preview_length]).to be_kind_of(Integer)
        expect(parsed.intrinsics[:preview_length]).to be > 0
      end
    end
  end

  describe 'is able to parse orientation info in the examples' do
    it 'is able to parse orientation in RAW_CANON_40D_SRAW_V103.CR2' do
      file = fixtures_dir + '/CR2/RAW_CANON_40D_SRAW_V103.CR2'
      parsed = subject.call(File.open(file, 'rb'))
      expect(parsed.orientation).to be_kind_of(Symbol)
      expect(parsed.image_orientation).to be_kind_of(Integer)
      expect(parsed.image_orientation).to be > 0
    end

    it 'is able to return the orientation nil for the examples from old Canon models' do
      file = fixtures_dir + '/CR2/_MG_8591.CR2'
      parsed = subject.call(File.open(file, 'rb'))
      expect(parsed.orientation).to be_nil
      expect(parsed.image_orientation).to be_nil
    end
  end

  describe 'is able to return nil unless the examples are CR2' do
    Dir.glob(fixtures_dir + '/TIFF/*.tif').each do |tiff_path|
      it "should return nil for #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))
        expect(parsed).to be_nil
      end
    end
  end
end
