require 'spec_helper'

describe FormatParser::ARWParser do
  describe 'matches filenames with valid extensions' do 
    filenames = ['raw_file', 'another raw file', 'and.another', 'one-more']
    extensions = ['.arw', '.Arw', '.aRw', '.arW', '.ARw', '.ArW', '.aRW', '.ARW']
    filenames.each do |filename|
      extensions.each do |extension|
        it "matches '#{filename + extension}'" do
          expect(subject.likely_match?(filename + extension)).to be_truthy
        end
      end
    end
  end

  describe 'does not match filenames with invalid extensions' do 
    filenames = ['raw_file', 'another raw file', 'and.another', 'one-more']
    extensions = ['.tiff', '.cr2', '.new', '.jpeg']
    filenames.each do |filename|
      extensions.each do |extension|
        it "does not match '#{filename + extension}'" do
          expect(subject.likely_match?(filename + extension)).to be_falsey
        end
      end
    end
  end
  
  it 'parses Sony ARW fixture as arw format file' do
    arw_path = fixtures_dir + '/ARW/RAW_SONY_ILCE-7RM2.ARW'

    parsed = subject.call(File.open(arw_path, 'rb'))

    expect(parsed).not_to be_nil
    expect(parsed.nature).to eq(:image)
    expect(parsed.format).to eq(:arw)

    expect(parsed.width_px).to eq(7952)
    expect(parsed.height_px).to eq(5304)
    expect(parsed.intrinsics[:exif]).not_to be_nil
    expect(parsed.content_type).to eq('image/x-sony-arw')
  end

  # TODO: add tests for other test files to ensure dimensions are always correctly parsed by exif parser
end
