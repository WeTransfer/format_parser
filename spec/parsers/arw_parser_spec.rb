require 'spec_helper'

describe FormatParser::ARWParser do
  shared_examples 'likely_match for file' do |filename_with_extension|
    it "matches '#{filename_with_extension}'" do
      expect(subject.likely_match?(filename_with_extension)).to be_truthy
    end
  end

  shared_examples 'no likely_match for file' do |filename_with_extension|
    it "does not match '#{filename_with_extension}'" do
      expect(subject.likely_match?(filename_with_extension)).to be_falsey
    end
  end

  describe 'likely_match' do
    filenames = ['raw_file', 'another raw file', 'and.another', 'one-more']
    valid_extensions = ['.arw', '.Arw', '.aRw', '.arW', '.ARw', '.ArW', '.aRW', '.ARW']
    invalid_extensions = ['.tiff', '.cr2', '.new', '.jpeg']
    filenames.each do |filename|
      valid_extensions.each do |extension|
        include_examples 'likely_match for file', filename + extension
      end
      invalid_extensions.each do |extension|
        include_examples 'no likely_match for file', filename + extension
      end
    end
  end

  describe 'parses Sony ARW fixtures as arw format file' do
    expected_parsed_dimensions = {
      'RAW_SONY_A100.ARW' => {
        width_px: 3872,
        height_px: 2592,
        display_width_px: 3872,
        display_height_px: 2592,
        orientation: :top_left
      },
      'RAW_SONY_A700.ARW' => {
        width_px: 4288,
        height_px: 2856,
        display_width_px: 4288,
        display_height_px: 2856,
        orientation: :top_left
      },
      'RAW_SONY_A900.ARW' => {
        width_px: 6080,
        height_px: 4048,
        display_width_px: 6080,
        display_height_px: 4048,
        orientation: :top_left
      },
      # rotated 90 degree image
      'RAW_SONY_DSC-RX100M2.ARW' => {
        width_px: 5472,
        height_px: 3648,
        display_width_px: 3648,
        display_height_px: 5472,
        orientation: :right_top,
      },
      'RAW_SONY_ILCE-7RM2.ARW' => {
        width_px: 7952,
        height_px: 5304,
        display_width_px: 7952,
        display_height_px: 5304,
        orientation: :top_left,
      },
      'RAW_SONY_NEX7.ARW' => {
        width_px: 6000,
        height_px: 4000,
        display_width_px: 6000,
        display_height_px: 4000,
        orientation: :top_left,
      },
      'RAW_SONY_SLTA55V.ARW' => {
        width_px: 4928,
        height_px: 3280,
        display_width_px: 4928,
        display_height_px: 3280,
        orientation: :top_left,
      },
    }

    Dir.glob(fixtures_dir + '/ARW/*.ARW').each do |arw_path|
      it "is able to parse #{File.basename(arw_path)}" do
        expected_dimension = expected_parsed_dimensions[File.basename(arw_path)]
        # error if a new .arw test file is added without specifying the expected dimensions
        expect(expected_dimension).not_to be_nil

        parsed = subject.call(File.open(arw_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:arw)
        expect(parsed.intrinsics[:exif]).not_to be_nil
        expect(parsed.content_type).to eq('image/x-sony-arw')

        expect(parsed.width_px).to eq(expected_dimension[:width_px])
        expect(parsed.height_px).to eq(expected_dimension[:height_px])
        expect(parsed.display_width_px).to eq(expected_dimension[:display_width_px])
        expect(parsed.display_height_px).to eq(expected_dimension[:display_height_px])
        expect(parsed.orientation).to eq(expected_dimension[:orientation])
      end
    end

    shared_examples 'invalid filetype' do |filetype, fixture_path|
      it "should fail to parse #{filetype}" do
        file_path = fixtures_dir + fixture_path
        parsed = subject.call(File.open(file_path, 'rb'))
        expect(parsed).to be_nil
      end
    end

    include_examples 'invalid filetype', 'NEF', '/NEF/RAW_NIKON_1S2.NEF'
    include_examples 'invalid filetype', 'TIFF', '/TIFF/Shinbutsureijoushuincho.tiff'
    include_examples 'invalid filetype', 'JPG', '/JPEG/orient_6.jpg'
    include_examples 'invalid filetype', 'PNG', '/PNG/cat.png'
    include_examples 'invalid filetype', 'CR2', '/CR2/RAW_CANON_1DM2.CR2'
  end
end
