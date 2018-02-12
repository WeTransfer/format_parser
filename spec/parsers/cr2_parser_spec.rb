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

        expect(parsed.resolution).to be_kind_of(Integer)
        expect(parsed.resolution).to be > 0
      end
    end
  end

  describe 'is able to parse preview image in the examples' do
    it 'is able to parse image in RAW_CANON_40D_SRAW_V103.CR2' do
      file = fixtures_dir + '/CR2/RAW_CANON_40D_SRAW_V103.CR2'
      parsed = subject.call(File.open(file, 'rb'))
      expect(parsed.preview).not_to be_nil

      file = Tempfile.new('parsed_image')
      file.write parsed.preview
      file.close

      parsed_image = FormatParser.parse(File.open(file.path, 'rb'))
      expect(parsed_image.nature).to eq(:image)
      expect(parsed_image.format).to eq(:jpg)
    end

    it 'is able to return the preview image nil when bytes are off limits' do
      file = fixtures_dir + '/CR2/RAW_CANON_1DM2.CR2'
      parsed = subject.call(File.open(file, 'rb'))
      expect(parsed.preview).to be_nil
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

  describe 'is able to return class constant variables' do
    it 'should return tiff header tag' do
      expect(FormatParser::CR2Parser::TIFF_HEADER).to eq [0x49, 0x49, 0x2a, 0x00]
    end
    it 'should return cr2 header tag' do
      expect(FormatParser::CR2Parser::CR2_HEADER).to eq [0x43, 0x52, 0x02, 0x00]
    end
    it 'should return preview orientation tag' do
      expect(FormatParser::CR2Parser::PREVIEW_ORIENTATION_TAG).to eq 0x0112
    end
    it 'should return preview orientation tag' do
      expect(FormatParser::CR2Parser::PREVIEW_RESOLUTION_TAG).to eq 0x011a
    end
    it 'should return preview offset tag' do
      expect(FormatParser::CR2Parser::PREVIEW_IMAGE_OFFSET_TAG).to eq 0x0111
    end
    it 'should return preview bytes length tag' do
      expect(FormatParser::CR2Parser::PREVIEW_IMAGE_BYTE_COUNT_TAG).to eq 0x0117
    end
  end

  describe 'is able to return nil unless the examples are CR2' do
    Dir.glob(fixtures_dir + '/TIFF/*.tif').each do |cr2_path|
      it "should return nil for #{File.basename(cr2_path)}" do
        parsed = subject.call(File.open(cr2_path, 'rb'))
        expect(parsed).to be_nil
      end
    end
  end
end
