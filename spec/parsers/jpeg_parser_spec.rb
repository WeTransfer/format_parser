require 'spec_helper'

describe FormatParser::JPEGParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(fixtures_dir + '/*.jpg').each do |jpeg_path|
      it "is able to parse #{File.basename(jpeg_path)}" do
        parsed = subject.call(File.open(jpeg_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:jpg)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  it 'is able to parse JPEG examples with EXIF tags containing different orientations from FastImage' do
    Dir.glob(fixtures_dir + '/exif-orientation-testimages/jpg/*.jpg').each do |jpeg_path|
      parsed = subject.call(File.open(jpeg_path, 'rb'))
      expect(parsed).not_to be_nil

      expect(parsed.orientation).to be_kind_of(Symbol)
      expect(parsed.width_px).to be > 0
      expect(parsed.height_px).to be > 0
    end

    bottom_left_path = fixtures_dir + '/exif-orientation-testimages/jpg/bottom_left.jpg'
    parsed = subject.call(File.open(bottom_left_path, 'rb'))
    expect(parsed.orientation).to eq(:bottom_left)
    expect(parsed.width_px).to eq(1240)
    expect(parsed.height_px).to eq(1754)

    top_right_path = fixtures_dir + '/exif-orientation-testimages/jpg/right_bottom.jpg'
    parsed = subject.call(File.open(top_right_path, 'rb'))
    expect(parsed.orientation).to eq(:right_bottom)
    expect(parsed.width_px).to eq(1754)
    expect(parsed.height_px).to eq(1240)
  end

  it 'gives true pixel dimensions priority over pixel dimensions in EXIF tags' do
    jpeg_path = fixtures_dir + '/JPEG/divergent_pixel_dimensions_exif.jpg'
    result = subject.call(File.open(jpeg_path, 'rb'))
    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1280)
    expect(result.intrinsics).to eq(exif_pixel_x_dimension: 8214, exif_pixel_y_dimension: 5476)
  end

  it 'reads an example with many APP1 markers at the beginning of which none are EXIF' do
    fixture_path = fixtures_dir + '/JPEG/too_many_APP1_markers_surrogate.jpg'
    io = FormatParser::ReadLimiter.new(File.open(fixture_path, 'rb'))

    result = subject.call(io)

    expect(result).not_to be_nil
    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1200)

    expect(io.bytes).to be < (128 * 1024)
    expect(io.reads).to be < (1024 * 4)
  end

  it 'does not continue parsing for inordinate amount of time if the file contains no 0xFF bytes' do
    # Create a large fuzzed input that consists of any bytes except 0xFF,
    # so that the marker detector has nothing to latch on to
    bytes_except_byte_255 = 0x0..0xFE

    # Start the blob with the usual SOI marker - 0xFF 0xD8, so that the parser does not
    # bail out too early and actually "bites" into the blob
    no_markers = ([0xFF, 0xD8] + (16 * 1024).times.map { rand(bytes_except_byte_255) }).pack('C*')

    # Yes, assertions on a private method - but we want to ensure we do not read more
    # single bytes than the restriction stipulates we may. At the same time we check that
    # the method does indeed, get triggered
    expect(subject).to receive(:read_char).at_least(100).times.at_most(1024).times.and_call_original
    result = subject.call(StringIO.new(no_markers))
    expect(result).to be_nil
  end

  it 'does not return a result for a Keynote document' do
    key_path = fixtures_dir + '/JPEG/keynote_recognized_as_jpeg.key'
    result = subject.call(File.open(key_path, 'rb'))
    expect(result).to be_nil
  end
end
