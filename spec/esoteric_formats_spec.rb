require 'spec_helper'

describe 'Parsing esoteric files and files causing ambiguous detection' do
  it 'correctly parses the test .docx files as Office docs' do
    docx_path = fixtures_dir + '/ZIP/10.docx'
    result = FormatParser.parse(File.open(docx_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:document)
  end

  it 'does not return a result for a Keynote file when it mistakes it for a JPEG, and does not raise any errors' do
    jpeg_path = fixtures_dir + '/JPEG/keynote_recognized_as_jpeg.key'
    result = FormatParser.parse(File.open(jpeg_path, 'rb'))
    expect(result.nature).to eq(:archive)
  end
end
