require 'spec_helper'

describe FormatParser::RW2Parser do
  describe '#likely_match?' do
    %w[rw2 RW2 raw RAW rwl RWL].each do |extension|
      context "with a file with a .#{extension} extension" do
        it "returns true" do
          expect(subject.likely_match?("foo.#{extension}")).to be(true)
        end
      end
    end

    ['', 'foo', 'rw2', 'foorw2', 'foo.rw', 'foo.rw2.bar'].each do |filename|
      context "with a file named #{filename}" do
        it 'returns false' do
          expect(subject.likely_match?(filename)).to be(false)
        end
      end
    end
  end

  describe '#call' do
    Dir.glob(fixtures_dir + '/RW2/*.*').sort.each do |path|
      it "successfully parses #{path}" do
        result = subject.call(File.open(path, 'rb'))

        expect(result).not_to be_nil
        expect(result.nature).to eq(:image)
        expect(result.format).to eq(:rw2)
        expect(result.width_px).to be > 0
        expect(result.height_px).to be > 0
        expect(result.content_type).to eq('image/x-panasonic-raw')
        expect(result.intrinsics).not_to be_nil
      end
    end

    %w[ARW/RAW_SONY_A100.ARW NEF/RAW_NIKON_D1X.NEF TIFF/test.tif].each do |path|
      it "does not parse #{path}" do
        result = subject.call(File.open(fixtures_dir + path, 'rb'))
        expect(result).to be_nil
      end
    end

    it 'parses metadata correctly' do
      file_path = fixtures_dir + '/RW2/Panasonic - DMC-G2 - 16_9.RW2'

      result = subject.call(File.open(file_path, 'rb'))
      expect(result.nature).to eq(:image)
      expect(result.format).to eq(:rw2)
      expect(result.width_px).to eq(4000)
      expect(result.height_px).to eq(2248)
      expect(result.orientation).to eq(:top_left)
      expect(result.display_width_px).to eq(4000)
      expect(result.display_height_px).to eq(2248)
      expect(result.content_type).to eq('image/x-panasonic-raw')
      expect(result.intrinsics).not_to be_nil
      expect(result.intrinsics[:exif]).not_to be_nil
    end
  end
end
