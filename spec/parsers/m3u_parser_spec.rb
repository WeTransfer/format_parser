require 'spec_helper'

describe FormatParser::M3UParser do
  let(:parsed_m3u) do
    subject.call(
      File.open(
        Pathname.new(fixtures_dir).join('M3U').join(m3u_file),
        'rb'
      )
    )
  end

  describe 'an m3u file with missing header' do
    let(:m3u_file) { 'plain_text.m3u' }

    it 'does not parse the file successfully' do
      expect(parsed_m3u).to be_nil
    end
  end

  describe 'an m3u file with valid header' do
    let(:m3u_file) { 'sample.m3u' }

    it 'parses the file successfully' do
      expect(parsed_m3u).not_to be_nil
      expect(parsed_m3u.nature).to eq(:text)
      expect(parsed_m3u.format).to eq(:m3u)
    end
  end

  describe 'an m3u8 file with valid header' do
    let(:m3u_file) { 'sample.m3u8' }

    it 'parses the file successfully' do
      expect(parsed_m3u).not_to be_nil
      expect(parsed_m3u.nature).to eq(:text)
      expect(parsed_m3u.format).to eq(:m3u)
    end
  end
end
