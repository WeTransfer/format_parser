require 'spec_helper'

describe FormatParser::MP3Parser do
  it 'decodes and estimates duration for a VBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_vbr.mp3'
    parsed = subject.information_from_io(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.file_nature).to eq(:audio)
    expect(parsed.file_type).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.836)
  end

  it 'decodes and estimates duration for a CBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_cbr.mp3'
    parsed = subject.information_from_io(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.file_nature).to eq(:audio)
    expect(parsed.file_type).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.81)
  end
end
