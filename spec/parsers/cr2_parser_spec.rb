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

        expect(parsed.orientation).not_to be_nil
      end
    end
  end

  it 'is able to parse orientation in RAW_CANON_40D_SRAW_V103.CR2' do
    file = fixtures_dir + '/CR2/RAW_CANON_40D_SRAW_V103.CR2'

    parsed = subject.call(File.open(file, 'rb'))

    expect(parsed.width_px).to eq(1936)
    expect(parsed.height_px).to eq(1288)
    expect(parsed.orientation).to be_kind_of(Symbol)
  end

  it 'is able to return the orientation nil for the examples from old Canon models' do
    file = fixtures_dir + '/CR2/_MG_8591.CR2'

    parsed = subject.call(File.open(file, 'rb'))

    expect(parsed.width_px).to eq(1536)
    expect(parsed.height_px).to eq(1024)
    expect(parsed.orientation).to eq(:top_left)
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
