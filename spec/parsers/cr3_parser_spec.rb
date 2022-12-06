require 'spec_helper'

describe FormatParser::CR3Parser do
  it 'should match valid CR3 file extensions' do
    valid_extensions = %w[cr3 cR3 Cr3 CR3]
    valid_extensions.each { |extension| expect(subject.likely_match?("foo.#{extension}")).to be_truthy }
  end

  it 'should not match invalid CR3 file extensions' do
    invalid_filenames = ['', 'foo', 'cr3', 'foocr3', 'foo.cr2', 'foo.cr3.bar']
    invalid_filenames.each { |filename| expect(subject.likely_match?(filename)).to be_falsey }
  end

  it 'should not parse a file that does not match the CR3 definition' do
    # MOV files are closely related to CR3 files (both extend the ISO Base File Format), so this is a decent edge case
    # to ensure only true CR3 files are being parsed.
    result = subject.call(File.open(fixtures_dir + '/MOOV/MOV/Test_Dimensions.mov'))
    expect(result).to be_nil
  end

  it 'should return nil if no CMT1 box is present' do
    # This is a MOV file with the ftyp header modified to masquerade as a CR3 file. It is therefore missing the
    # CR3-specific CMT1 box containing the image metadata.
    result = subject.call(File.open(fixtures_dir + '/CR3/invalid'))
    expect(result).to be_nil
  end

  Dir.glob(fixtures_dir + '/CR3/*.cr3').sort.each do |file_path|
    it "successfully parses #{File.basename(file_path)}" do
      result = subject.call(File.open(file_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:image)
      expect(result.width_px).to be > 0
      expect(result.height_px).to be > 0
      expect(result.content_type).to eq('image/x-canon-cr3')
      expect(result.intrinsics).not_to be_nil
    end
  end

  it 'parses the necessary metadata from a CR3 file' do
    file_path = fixtures_dir + '/CR3/Canon EOS R10 (RAW).CR3'

    result = subject.call(File.open(file_path, 'rb'))
    expect(result.nature).to eq(:image)
    expect(result.width_px).to eq(6000)
    expect(result.height_px).to eq(4000)
    expect(result.orientation).to eq(:top_left)
    expect(result.display_width_px).to eq(6000)
    expect(result.display_height_px).to eq(4000)
    expect(result.content_type).to eq('image/x-canon-cr3')
    expect(result.intrinsics).not_to be_nil
    expect(result.intrinsics[:box_tree]).not_to be_nil
    expect(result.intrinsics[:exif]).not_to be_nil
    expect(result.intrinsics[:exif][:image_length]).to eq(result.height_px)
    expect(result.intrinsics[:exif][:image_width]).to eq(result.width_px)
  end
end
