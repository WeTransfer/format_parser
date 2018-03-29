require 'spec_helper'

describe FormatParser::FLACParser do
  it 'decodes and estimates duration for the atc_fixture_vbr FLAC File' do
    fpath = fixtures_dir + 'FLAC/atc_fixture_vbr.flac'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:flac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_frames).to eq(33810)
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.836)
  end

  it 'decodes and estimates duration for the 16bit FLAC File' do
    fpath = fixtures_dir + 'FLAC/c_11k16bitpcm.flac'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:flac)
    expect(parsed.intrinsics[:bits_per_sample]).to eq(16)
    expect(parsed.num_audio_channels).to eq(1)
    expect(parsed.audio_sample_rate_hz).to eq(11025)
    expect(parsed.media_duration_frames).to eq(152267)
    expect(parsed.media_duration_seconds).to be_within(0.01).of(13.81)
  end

  it 'raises error on parsing an invalid file' do
    fpath = fixtures_dir + 'FLAC/invalid.flac'

    expect {
      subject.call(File.open(fpath, 'rb'))
    }.to raise_error(FormatParser::IOUtils::InvalidRead)
  end

  it 'raises error on parsing a file with an invalid block size' do
    fpath = fixtures_dir + 'FLAC/invalid_minimum_block_size.flac'

    expect {
      subject.call(File.open(fpath, 'rb'))
    }.to raise_error(FormatParser::IOUtils::MalformedFile)

    fpath = fixtures_dir + 'FLAC/invalid_maximum_block_size.flac'

    expect {
      subject.call(File.open(fpath, 'rb'))
    }.to raise_error(FormatParser::IOUtils::MalformedFile)
  end

  it 'raises an error when sample rate is 0' do
    fpath = fixtures_dir + 'FLAC/sample_rate_0.flac'

    expect {
      subject.call(File.open(fpath, 'rb'))
    }.to raise_error(FormatParser::IOUtils::MalformedFile)
  end
end
