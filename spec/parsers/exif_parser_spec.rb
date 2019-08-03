require 'spec_helper'

describe FormatParser::EXIFParser do
  let(:subject) do
    Object.new.tap { |o| o.extend FormatParser::EXIFParser }
  end

  describe 'is able to correctly parse orientation for all the TIFF EXIF examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      filename = File.basename(tiff_path)
      it "is able to parse #{filename}" do
        result = subject.exif_from_tiff_io(File.open(tiff_path, 'rb'))
        expect(result).not_to be_nil
        expect(result.orientation_sym).to be_kind_of(Symbol)
        # Filenames in this dir correspond with the orientation of the file
        expect(filename).to include(result.orientation_sym.to_s)
      end
    end
  end

  describe 'IOExt' do
    it 'supports readbyte' do
      io = FormatParser::EXIFParser::IOExt.new(StringIO.new('hello'))
      expect(io.readbyte).to eq(104)
    end

    it 'supports getbyte' do
      io = FormatParser::EXIFParser::IOExt.new(StringIO.new('hello'))
      expect(io.getbyte).to eq(104)
    end

    it 'supports seek modes' do
      io = FormatParser::EXIFParser::IOExt.new(StringIO.new('hello'))
      io.seek(1, IO::SEEK_SET)

      io.seek(1, IO::SEEK_CUR)
      expect(io.read(1)).to eq('l')

      io.seek(-1, IO::SEEK_END)
      expect(io.read(1)).to eq('o')

      io.seek(1)
      expect(io.read(1)).to eq('e')
    end
  end
end
