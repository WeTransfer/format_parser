require 'spec_helper'

describe FormatParser::AACParser do
  it 'can parse a short sample, single channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/gs-16b-1c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(1)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'can parse a short sample, two channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/gs-16b-2c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'can parse a long sample, single channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/ff-16b-1c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(1)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'can parse a long sample, two channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/ff-16b-2c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end
end
