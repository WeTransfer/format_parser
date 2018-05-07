require 'spec_helper'

describe FormatParser::MP3Parser do
  it 'decodes and estimates duration for a VBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_vbr.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.836)
  end

  it 'decodes and estimates duration for a CBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_cbr.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.81)
  end

  it 'parses the Cassy MP3' do
    fpath = fixtures_dir + '/MP3/Cassy.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.media_duration_seconds).to be_within(0.1).of(1102.46)

    expect(parsed.intrinsics).not_to be_nil

    i = parsed.intrinsics
    expect(i[:artist]).to eq('WeTransfer Studios/GIlles Peterson')
    expect(i[:title]).to eq('Cassy')
    expect(i[:album]).to eq('The Psychology of DJing')
    expect(i[:comments]).to eq('0')
    expect(i[:id3tags]).not_to be_nil

    expect(parsed.intrinsics).not_to be_nil
  end

  it 'avoids returning a result when the parsed duration is infinite' do
    fpath = fixtures_dir + '/JPEG/too_many_APP1_markers_surrogate.jpg'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).to be_nil
  end
end
