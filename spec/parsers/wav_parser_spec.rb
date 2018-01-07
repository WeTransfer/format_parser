require 'spec_helper'

describe FormatParser::WAVParser do
  Dir.glob(fixtures_dir + '/WAV/c*.*').each do |wav_path|
    it "is able to parse #{File.basename(wav_path)}" do
      parse_result = subject.information_from_io(File.open(wav_path, 'rb'))

      expect(parse_result.file_nature).to eq(:audio)
      expect(parse_result.file_type).to eq(:wav)
      expect(parse_result.num_audio_channels).to eq(2)
      expect(parse_result.audio_sample_rate_hz).to eq(44100)
      expect(parse_result.media_duration_frames).to eq(197799)
      expect(parse_result.media_duration_seconds).to be_within(0.01).of(4.48)
    end
  end

  Dir.glob(fixtures_dir + '/WAV/d*.*').each do |wav_path|
    it "cannot parse #{File.basename(wav_path)}" do
      parse_result = subject.information_from_io(File.open(wav_path, 'rb'))

      expect(parse_result).to be_nil
    end
  end
end
