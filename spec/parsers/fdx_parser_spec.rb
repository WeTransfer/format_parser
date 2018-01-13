require 'spec_helper'

describe FormatParser::FDXParser do
  describe 'is able to parse the sample file' do
    Dir.glob(fixtures_dir + '/*.fdx').each do |fdx_path|
      it "is able to parse #{File.basename(fdx_path)}" do
        parsed = subject.information_from_io(File.open(fdx_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.file_nature).to eq(:document)
        expect(parsed.file_type).to eq(:fdx)
      end
    end
  end
end
