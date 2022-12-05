require 'spec_helper'

describe FormatParser::RW2Parser do
  context 'when likely_match? is called' do
    %w[rw2 RW2 raw RAW rwl RWL].each do |extension|
      context "with a file with a .#{extension} extension" do
        it "should return true" do
          expect(subject.likely_match?("foo.#{extension}")).to be_truthy
        end
      end
    end

    ['', 'foo', 'rw2', 'foorw2', 'foo.rw', 'foo.rw2.bar'].each do |filename|
      context "with a file named #{filename}" do
        it 'should return false' do
          expect(subject.likely_match?(filename)).to be_falsey
        end
      end
    end
  end

  context 'when call is called' do
    Dir.glob(fixtures_dir + '/RW2/*.*').sort.each do |path|
      it "should successfully parse #{path}" do
        result = subject.call(File.open(path, 'rb'))

        expect(result).not_to be_nil
        expect(result.nature).to eq(:image)
        expect(result.width_px).to be > 0
        expect(result.height_px).to be > 0
        expect(result.content_type).to eq('image/x-panasonic-raw')
        expect(result.intrinsics).not_to be_nil
      end
    end

    %w[ARW/RAW_SONY_A100.ARW NEF/RAW_NIKON_D1X.NEF TIFF/test.tif].each do |path|
      it "should not parse #{path}" do
        result = subject.call(File.open(fixtures_dir + path, 'rb'))
        expect(result).to be_nil
      end
    end

    it 'parses the necessary metadata from an RW2 file' do
      file_path = fixtures_dir + '/RW2/Panasonic - DMC-G2 - 16_9.RW2'

      result = subject.call(File.open(file_path, 'rb'))
      expect(result.nature).to eq(:image)
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
