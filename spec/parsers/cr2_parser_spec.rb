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

      end
    end
  end
end
