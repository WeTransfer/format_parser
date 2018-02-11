require 'spec_helper'

describe FormatParser::CR2Parser do
  describe 'is able to parse all CR2 files' do
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

        expect(parsed.orientation).to be_kind_of(Symbol)
        expect(parsed.image_orientation).to be_kind_of(Integer)
        expect(parsed.image_orientation).to be > 0

        expect(parsed.resolution).to be_kind_of(Integer)
        expect(parsed.resolution).to be > 0
      end
    end
  end

  describe 'returns nil unless files are CR2' do
    Dir.glob(fixtures_dir + '/PNG/*.png').each do |cr2_path|
      it "should return nil for #{File.basename(cr2_path)}" do
        parsed = subject.call(File.open(cr2_path, 'rb'))
        expect(parsed).to be_nil
      end
    end
  end
end
