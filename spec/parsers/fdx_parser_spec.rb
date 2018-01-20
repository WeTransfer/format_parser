require 'spec_helper'

describe FormatParser::FDXParser do
  describe 'is able to parse the sample file' do
    Dir.glob(fixtures_dir + '/XML/*.fdx').each do |fdx_path|
      it "is able to parse #{File.basename(fdx_path)}" do
        parsed = subject.call(File.open(fdx_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:document)
        expect(parsed.format).to eq(:fdx)
        expect(parsed.document_type).to eq(:script)
      end
    end
  end

  describe 'does not parse other XML files as FDX' do
    Dir.glob(fixtures_dir + '/*.svg').each do |svg_path|
      it 'returns nil when parsing a non-fdx xml file' do
        parsed = subject.call(File.open(svg_path, 'rb'))
        expect(parsed).to eq(nil)
      end
    end
  end
end
