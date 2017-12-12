require 'spec_helper'

describe FormatParser::PNGParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/*.png').each do |png_path|
      it "is able to parse #{File.basename(png_path)}" do
        parsed = subject.information_from_io(File.open(png_path, 'rb'))
        expect(parsed).not_to be_nil

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end
  
  it 'is able to parse the PNG even if the IHDR chunk is not the first in the file' do
    bad_png = StringIO.new
    bad_png << [137, 80, 78, 71, 13, 10, 26, 10].pack("C*")
    bad_png << [48].pack("N")
    bad_png << "FOO1"
    bad_png << Random.new.bytes(48)
    bad_png << [8+5].pack('N')
    bad_png << "IHDR"
    bad_png << [120, 130].pack('N2')
    bad_png << Random.new.bytes(5)

    result = subject.information_from_io(bad_png)

    expect(result).not_to be_nil
    expect(result.width_px).to eq(120)
    expect(result.height_px).to eq(130)
  end
end
