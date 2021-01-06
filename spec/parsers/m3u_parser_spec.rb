require 'spec_helper'

describe FormatParser::M3UParser do
  let(:parsed_m3u) {
    subject.call(
      File.open(
        Pathname.new(fixtures_dir).join('M3U').join(m3u_file),
        'rb'
      )
    )
  }
  let(:file_content) { "\n#EXTINF:170,Artist - 1\nC:\\My Music\\Artist\\Year\\1.Test.mp3\n#EXTINF:3,Artist - 10\nC:\\My Music\\Artist\\Year\\10.Test.mp3\n" }

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
      expect(parsed_m3u.size).to eq(124)
      expect(parsed_m3u.content).to eq(file_content)
    end
  end

  describe 'an m3u8 file with valid header' do
    let(:m3u_file) { 'sample.m3u8' }

    it 'parses the file successfully' do
      expect(parsed_m3u).not_to be_nil
      expect(parsed_m3u.nature).to eq(:text)
      expect(parsed_m3u.format).to eq(:m3u)
      expect(parsed_m3u.size).to eq(124)
      expect(parsed_m3u.content).to eq(file_content)
    end
  end
end
