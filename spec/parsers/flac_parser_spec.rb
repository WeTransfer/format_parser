require 'spec_helper'

describe FormatParser::FLACParser do
  it 'decodes and estimates duration for a FLAC File' do
    fpath = fixtures_dir + '/FLAC/atc_fixture_vbr.flac'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:flac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.836)
  end
end
