require 'spec_helper'

describe FormatParser::PSDParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/*.psd').each do |psd_path|
      it "is able to parse #{File.basename(psd_path)}" do
        parsed = subject.information_from_io(File.open(psd_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.file_nature).to eq(:image)
        expect(parsed.file_type).to eq(:psd)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end
end
