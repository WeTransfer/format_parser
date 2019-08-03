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
      expect(parsed.display_width_px).to eq(1240)
      expect(parsed.display_height_px).to eq(1754)
    end

    bottom_left_path = fixtures_dir + '/exif-orientation-testimages/jpg/bottom_left.jpg'
    parsed = subject.call(File.open(bottom_left_path, 'rb'))
    expect(parsed.orientation).to eq(:bottom_left)
    expect(parsed.width_px).to eq(1240)
    expect(parsed.height_px).to eq(1754)
    expect(parsed.display_width_px).to eq(1240)
    expect(parsed.display_height_px).to eq(1754)
    expect(parsed.intrinsics[:exif]).not_to be_nil

    top_right_path = fixtures_dir + '/exif-orientation-testimages/jpg/right_bottom.jpg'
    parsed = subject.call(File.open(top_right_path, 'rb'))
    expect(parsed.orientation).to eq(:right_bottom)
    expect(parsed.width_px).to eq(1754)
    expect(parsed.height_px).to eq(1240)
    expect(parsed.display_width_px).to eq(1240)
    expect(parsed.display_height_px).to eq(1754)
    expect(parsed.intrinsics[:exif]).not_to be_nil
  end

  it 'gives true pixel dimensions priority over pixel dimensions in EXIF tags' do
    jpeg_path = fixtures_dir + '/JPEG/divergent_pixel_dimensions_exif.jpg'
    result = subject.call(File.open(jpeg_path, 'rb'))

    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1280)

    exif = result.intrinsics.fetch(:exif)
    expect(exif.pixel_x_dimension).to eq(8214)
    expect(exif.pixel_y_dimension).to eq(5476)
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
    allow(subject).to receive(:read_char).and_call_original
    result = subject.call(StringIO.new(no_markers))
    expect(result).to be_nil
    expect(subject).to have_received(:read_char).at_most(1026).times
  end

  it 'does not return a result for a Keynote document' do
    key_path = fixtures_dir + '/JPEG/keynote_recognized_as_jpeg.key'
    result = subject.call(File.open(key_path, 'rb'))
    expect(result).to be_nil
  end

  it 'parses the the marker structure correctly when marker bytes cannot be read in groups of 2' do
    kitten_path = fixtures_dir + '/JPEG/off-cadence-markers.jpg'
    result = subject.call(File.open(kitten_path, 'rb'))
    expect(result).not_to be_nil
  end

  it 'assigns correct orientation to the picture that has mutliple APP1 markers with EXIF tags' do
    # https://github.com/sdsykes/fastimage/issues/102
    # This case is peculiar in that (from what I could find)
    # it is not really _defined_ which EXIF comment in the file should be considered
    # the only one to be used, or whether they have to be "union'd" together, or tags
    # coming later in the file should overwrite tags that occur earlier. From what I
    # can observe the dimensions we are recovering here are correct and the rotation
    # is correctly detected, but I am not entirely sure how FastImage needs to play
    # it in this case.
    pic_path = fixtures_dir + '/JPEG/orient_6.jpg'
    result = subject.call(File.open(pic_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.width_px).to eq(2500)
    expect(result.display_width_px).to eq(1250) # The image is actually rotated
  end

  it 'outputs EXIF with binary data in such a way that it can be JSON-serialized' do
    pic_path = fixtures_dir + '/JPEG/exif-with-binary-bytes-in-fields.jpg'

    result = subject.call(File.open(pic_path, 'rb'))
    expect(result).not_to be_nil

    serialized = JSON.pretty_generate(result)
    expect(serialized).to be_kind_of(String)
  end

  it 'correctly recognizes various EXIF orientations' do
    (0..4).each do |n|
      path = fixtures_dir + "/exif-orientation-testimages/manipulated/Landscape_#{n}.jpg"
      result = subject.call(File.open(path, 'rb'))
      expect(result.display_width_px).to eq(1600)
      expect(result.display_height_px).to eq(1200)
    end
    (5..8).each do |n|
      path = fixtures_dir + "/exif-orientation-testimages/manipulated/Landscape_#{n}.jpg"
      result = subject.call(File.open(path, 'rb'))
      expect(result.display_width_px).to eq(1600)
      expect(result.display_height_px).to eq(1200)
    end
    (0..4).each do |n|
      path = fixtures_dir + "/exif-orientation-testimages/manipulated/Portrait_#{n}.jpg"
      result = subject.call(File.open(path, 'rb'))
      expect(result.display_width_px).to eq(1200)
      expect(result.display_height_px).to eq(1600)
    end
    (5..8).each do |n|
      path = fixtures_dir + "/exif-orientation-testimages/manipulated/Portrait_#{n}.jpg"
      result = subject.call(File.open(path, 'rb'))
      expect(result.display_width_px).to eq(1200)
      expect(result.display_height_px).to eq(1600)
    end
  end
end
