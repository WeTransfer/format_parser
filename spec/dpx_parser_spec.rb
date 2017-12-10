require 'spec_helper'

describe FormatParser::DPXParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/dpx/*.*').each do |dpx_path|
      it "is able to parse #{File.basename(dpx_path)}" do
        parsed = subject.information_from_io(File.open(dpx_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0
        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0
      end
    end
  end
end
