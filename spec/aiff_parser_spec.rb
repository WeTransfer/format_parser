require 'spec_helper'

describe FormatParser::AIFFParser do
  it 'parses an AIFF sample file' do
    parse_result = subject.call(File.open(__dir__ + '/fixtures/AIFF/fixture.aiff', 'rb'))

    expect(parse_result.nature).to eq(:audio)
    expect(parse_result.format).to eq(:aiff)
    expect(parse_result.media_duration_frames).to eq(46433)
    expect(parse_result.num_audio_channels).to eq(2)
    expect(parse_result.audio_sample_rate_hz).to be_within(0.01).of(44100)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(1.05)
  end

  it 'parses a Logic Pro created AIFF sample file having a COMT chunk before a COMM chunk' do
    parse_result = subject.call(File.open(__dir__ + '/fixtures/AIFF/fixture-logic-aiff.aif', 'rb'))

    expect(parse_result.nature).to eq(:audio)
    expect(parse_result.format).to eq(:aiff)
    expect(parse_result.media_duration_frames).to eq(302400)
    expect(parse_result.num_audio_channels).to eq(2)
    expect(parse_result.audio_sample_rate_hz).to be_within(0.01).of(44100)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(6.85)
  end
end
