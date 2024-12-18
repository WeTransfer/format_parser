require 'spec_helper'

describe FormatParser::AACParser do
  it 'should match filenames with valid AAC extensions' do
    filenames = ['audiofile', 'audio_file', 'audio-file', 'audio file', 'audio.file']
    extensions = ['.aac', '.AAC', '.Aac', '.AAc', '.aAc', '.aAC', '.aaC']
    filenames.each do |filename|
      extensions.each do |extension|
        expect(subject.likely_match?(filename + extension)).to be_truthy
      end
    end
  end

  it 'should not match filenames with invalid AAC extensions' do
    extensions = ['.aa', '.ac', '.acc', '.mp3', '.ogg', '.wav', '.flac', '.m4a', '.m4b', '.m4p', '.m4r', '.3gp']
    extensions.each do |extension|
      expect(subject.likely_match?('audiofile' + extension)).to be_falsey
    end
  end

  it 'should parse a short sample, single channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/gs-16b-1c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(1)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'should parse a short sample, two channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/gs-16b-2c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'should parse a long sample, single channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/ff-16b-1c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(1)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  it 'should parse a long sample, two channel audio, 16 kb/s, 44100 HZ' do
    file_path = fixtures_dir + '/AAC/ff-16b-2c-44100hz.aac'
    parsed = subject.call(File.open(file_path, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:aac)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.content_type).to eq('audio/aac')
  end

  shared_examples 'invalid filetype' do |filetype, fixture_path|
    it "should fail to parse #{filetype}" do
      file_path = fixtures_dir + fixture_path
      parsed = subject.call(File.open(file_path, 'rb'))
      expect(parsed).to be_nil
    end
  end

  include_examples 'invalid filetype', 'AIFF', '/AIFF/fixture.aiff'
  include_examples 'invalid filetype', 'FLAC', '/FLAC/atc_fixture_vbr.flac'
  include_examples 'invalid filetype', 'MP3', '/MP3/Cassy.mp3'
  include_examples 'invalid filetype', 'MPG', '/MPG/video1.mpg'
  include_examples 'invalid filetype', 'OGG', '/Ogg/hi.ogg'
  include_examples 'invalid filetype', 'WAV', '/WAV/c_8kmp316.wav'
end
