require 'spec_helper'

describe FormatParser::MP3Parser do
  describe 'is able to parse all our examples' do
    Dir.glob(fixtures_dir + '/MP3/*.*').each do |mp3_path|
      it "is able to parse #{File.basename(mp3_path)}" do
        parsed = subject.information_from_io(File.open(mp3_path, 'rb'))

        expect(parsed).not_to be_nil
      end
    end
  end
  
  it 'decodes syncsafe integers' do
    encoded = subject.encode_syncsafe_int(255)
    expect(encoded).to eq(383)

    decoded = subject.decode_syncsafe_int(encoded)
    expect(decoded).to eq(255)
  end
end
