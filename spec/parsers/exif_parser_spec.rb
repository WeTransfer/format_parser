require 'spec_helper'

describe FormatParser::EXIFParser do
  describe 'EXIFParser#exif_from_tiff_io' do
    describe 'Orientation' do
      describe 'is able to correctly parse orientation for all the TIFF EXIF examples from FastImage' do
        Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
          filename = File.basename(tiff_path)
          it "is able to parse #{filename}" do
            result = described_class.exif_from_tiff_io(File.open(tiff_path, 'rb'))
            expect(result).not_to be_nil
            expect(result.orientation_sym).to be_kind_of(Symbol)
            # Filenames in this dir correspond with the orientation of the file
            expect(filename).to include(result.orientation_sym.to_s)
          end
        end
      end

      it 'is able to deal with an orientation tag which a tuple value for orientation' do
        path = fixtures_dir + '/EXIF/double_orientation.exif.bin'
        exif_data = File.open(path, 'rb') do |f|
          described_class.exif_from_tiff_io(f)
        end
        expect(exif_data.orientation).to eq(1)
      end
    end

    describe 'SubIFDs' do
      it 'should not retrieve subIFDs data by default' do
        path = fixtures_dir + 'NEF/RAW_NIKON_D40_SRGB.NEF'

        exif_data = File.open(path, 'rb') do |f|
          described_class.exif_from_tiff_io(f)
        end

        expect(exif_data.sub_ifds_data).not_to be_nil
        expect(exif_data.sub_ifds_data).to eq({})
      end

      it 'is able retrieve data from all subIFDs optionally' do
        # Verifying:
        # {
        #    offset_1 => { subIFD_1 data...}
        #    offset_2 => { subIFD_2 data...}
        # }

        path = fixtures_dir + 'NEF/RAW_NIKON_D40_SRGB.NEF'
        should_include_sub_ifds = true

        exif_data = File.open(path, 'rb') do |f|
          described_class.exif_from_tiff_io(f, should_include_sub_ifds)
        end

        offset_1, offset_2 = exif_data.sub_ifds
        sub_ifds_data = exif_data.sub_ifds_data

        expect(sub_ifds_data).not_to be_nil
        expect(sub_ifds_data).to have_key(offset_1)
        expect(sub_ifds_data).to have_key(offset_2)
      end

      it 'returns EXIFR IFD instances as subIFD data' do
        # Verifying:
        # {
        #    offset_1 => { new_subfile_type => 1, ...}
        #    offset_2 => { new_subfile_type => 0, ...}
        # }
        # we shouldn't verify everything, since we trust to EXIFR for that.
        # making sure we are getting each subfile type should be good enough.

        path = fixtures_dir + 'NEF/RAW_NIKON_D40_SRGB.NEF'
        should_include_sub_ifds = true

        exif_data = File.open(path, 'rb') do |f|
          described_class.exif_from_tiff_io(f, should_include_sub_ifds)
        end

        offset_1, offset_2 = exif_data.sub_ifds.sort
        first_sub_ifd = exif_data.sub_ifds_data&.[](offset_1)
        second_sub_ifd = exif_data.sub_ifds_data&.[](offset_2)

        expect(first_sub_ifd).to be_kind_of(EXIFR::TIFF::IFD)
        expect(second_sub_ifd).to be_kind_of(EXIFR::TIFF::IFD)
        expect(first_sub_ifd.new_subfile_type).to eq(1)
        expect(second_sub_ifd.new_subfile_type).to eq(0)
      end
    end
  end

  describe 'EXIFStack' do
    it 'supports respond_to? for methods it does not have' do
      # Peculiar thing: we need to support respond_to?(:to_hash)
      # for compatibility with ActiveSupport JSON output. When you call as_json
      # on an object ActiveSupport implements that as_json method and will then
      # call #as_json on the contained objects as necessary, _or_ call
      # other methods if it thinks it is necessary.
      #
      # Although we _will_ be implementing to_hash specifically
      # the respond_to_missing must be implemented correctly
      stack = FormatParser::EXIFParser::EXIFStack.new([{}, {}])
      expect(stack).not_to respond_to(:no_such_method__at_all)
    end

    it 'returns a Hash from #to_hash' do
      first_fake_exif = double(orientation: 1, to_hash: {foo: 123, bar: 675})
      second_fake_exif = double(orientation: 4, to_hash: {foo: 245})

      stack = FormatParser::EXIFParser::EXIFStack.new([first_fake_exif, second_fake_exif])
      stack_as_hash = stack.to_hash

      # In this instance we DO need an actual type_check, because #to_hash
      # is used by default type coercions in Ruby
      expect(stack_as_hash).to be_kind_of(Hash)
      expect(stack_as_hash).to eq(foo: 245, bar: 675, orientation: 4)
    end
  end

  it 'is able to deal with an orientation tag which a tuple value for orientation' do
    path = fixtures_dir + '/EXIF/double_orientation.exif.bin'
    exif_data = File.open(path, 'rb') do |f|
      described_class.exif_from_tiff_io(f)
    end
    expect(exif_data.orientation).to eq(1)
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
