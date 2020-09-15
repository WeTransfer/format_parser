require 'spec_helper'

describe FormatParser::TIFFParser do
  describe 'with FastImage TIFF examples' do
    Dir.glob(fixtures_dir + '/TIFF/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:tif)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  it 'extracts dimensions from a very large TIFF economically' do
    tiff_path = fixtures_dir + '/TIFF/Shinbutsureijoushuincho.tiff'

    io = File.open(tiff_path, 'rb')
    io_with_stats = FormatParser::ReadLimiter.new(io)

    parsed = subject.call(io_with_stats)

    expect(parsed).not_to be_nil
    expect(parsed.width_px).to eq(1120)
    expect(parsed.height_px).to eq(1559)

    expect(io_with_stats.reads).to be_within(4).of(4)
    expect(io_with_stats.seeks).to be_within(4).of(4)
    expect(io_with_stats.bytes).to be_within(1024).of(8198)
  end

  it 'correctly extracts dimensions for one fixture' do
    tiff_path = fixtures_dir + '/TIFF/IMG_9266_8b_rgb_le_interleaved.tif'

    parsed = subject.call(File.open(tiff_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.width_px).to eq(320)
    expect(parsed.height_px).to eq(240)
    expect(parsed.intrinsics[:exif]).not_to be_nil
  end

  it 'parses Sony ARW fixture as raw format file' do
    arw_path = fixtures_dir + '/ARW/RAW_SONY_ILCE-7RM2.ARW'

    parsed = subject.call(File.open(arw_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:arw)

    expect(parsed.width_px).to eq(7952)
    expect(parsed.height_px).to eq(5304)
    expect(parsed.intrinsics[:exif]).not_to be_nil
  end

  describe 'correctly extracts dimensions from various TIFF flavors of the same file' do
    Dir.glob(fixtures_dir + '/TIFF/IMG_9266*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:tif)

        expect(parsed.width_px).to eq(320)
        expect(parsed.height_px).to eq(240)
      end
    end
  end

  describe 'is able to parse all the TIFF exif examples from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/tiff-*/*.tif').each do |tiff_path|
      it "is able to parse #{File.basename(tiff_path)}" do
        parsed = subject.call(File.open(tiff_path, 'rb'))
        expect(parsed).not_to be_nil

        expect(parsed.orientation).to be_kind_of(Symbol)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  describe 'bails out on CR2 files, such as' do
    Dir.glob(fixtures_dir + '/CR2/*.CR2').each do |cr2_path|
      it "skips #{File.basename(cr2_path)}" do
        parsed = subject.call(File.open(cr2_path, 'rb'))
        expect(parsed).to be_nil
      end
    end
  end
end
