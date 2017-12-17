require 'spec_helper'

describe FormatParser::AIFFParser do
  it 'parses a sample file' do
    parse_result = subject.information_from_io(File.open(__dir__ + '/fixtures/AIFF/Submarine.aiff', 'rb'))

    expect(parse_result.file_nature).to eq(:audio)
    expect(parse_result.media_duration_frames).to eq(59633)
    expect(parse_result.num_audio_channels).to eq(2)
    expect(parse_result.audio_sample_rate_hz).to be_within(0.01).of(48000)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(1.24)
  end
end
