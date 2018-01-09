require 'spec_helper'

describe FormatParser::WAVParser do
  # Fixtures prefixed with c_ are considered canonical
  # while fixtures prefixed with d_ deviate from the standard.
  Dir.glob(fixtures_dir + '/WAV/c_*.*').each do |wav_path|
    it "is able to parse #{File.basename(wav_path)}" do
      parse_result = subject.information_from_io(File.open(wav_path, 'rb'))

      expect(parse_result.file_nature).to eq(:audio)
      expect(parse_result.file_type).to eq(:wav)
    end
  end

  it "returns correct info about pcm files" do
    parse_result = subject.information_from_io(File.open(__dir__ + '/../fixtures/WAV/c_8kmp316.wav', 'rb'))

    expect(parse_result.file_nature).to eq(:audio)
    expect(parse_result.file_type).to eq(:wav)
    expect(parse_result.num_audio_channels).to eq(1)
    expect(parse_result.audio_sample_rate_hz).to eq(8000)
    expect(parse_result.media_duration_frames).to eq(110488)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(13.81)
  end

  it "returns correct info about pcm files with more channels" do
    parse_result = subject.information_from_io(File.open(__dir__ + '/../fixtures/WAV/c_39064__alienbomb__atmo-truck.wav', 'rb'))

    expect(parse_result.file_nature).to eq(:audio)
    expect(parse_result.file_type).to eq(:wav)
    expect(parse_result.num_audio_channels).to eq(2)
    expect(parse_result.audio_sample_rate_hz).to eq(44100)
    expect(parse_result.media_duration_frames).to eq(162832)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(3.69)
  end

  it "returns correct info about non pcm files" do
    parse_result = subject.information_from_io(File.open(__dir__ + '/../fixtures/WAV/c_11k16bitpcm.wav', 'rb'))

    expect(parse_result.file_nature).to eq(:audio)
    expect(parse_result.file_type).to eq(:wav)
    expect(parse_result.num_audio_channels).to eq(1)
    expect(parse_result.audio_sample_rate_hz).to eq(11025)
    expect(parse_result.media_duration_frames).to eq(152267)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(13.81)
  end

  it "cannot parse file with audio format different from 1 and no 'fact' chunk" do
    expect {
      subject.information_from_io(File.open(__dir__ + '/../fixtures/WAV/d_6_Channel_ID.wav', 'rb'))
    }.to raise_error(FormatParser::IOUtils::InvalidRead)
  end
end
