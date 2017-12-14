require 'spec_helper'

describe FormatParser::DPXParser do
  describe 'with Depix example files' do
    Dir.glob(__dir__ + '/fixtures/dpx/*.*').each do |dpx_path|
      it "is able to parse #{File.basename(dpx_path)}" do
        parsed = subject.information_from_io(File.open(dpx_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.file_nature).to eq(:image)
        expect(parsed.file_type).to eq(:dpx)

        # If we have an error in the struct offsets these values are likely to become
        # the maximum value of a 4-byte uint, which is way higher
        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be_between(0, 2048)
        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be_between(0, 4000)
      end
    end

    it 'correctly reads pixel dimensions' do
      fi = File.open(__dir__ + '/fixtures/dpx/026_FROM_HERO_TAPE_5-3-1_MOV.0029.dpx', 'rb')
      parsed = subject.information_from_io(fi)
      expect(parsed.width_px).to eq(1920)
      expect(parsed.height_px).to eq(1080)
    end
  end
end
