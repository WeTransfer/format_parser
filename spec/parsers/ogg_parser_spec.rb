require 'spec_helper'

describe FormatParser::OggParser do
  it 'parses an ogg file' do
    parse_result = subject.call(File.open(__dir__ + '/../fixtures/ogg_vorbis.ogg', 'rb'))

    expect(parse_result.nature).to eq(:audio)
    expect(parse_result.format).to eq(:ogg)
    expect(parse_result.num_audio_channels).to eq(1)
    expect(parse_result.audio_sample_rate_hz).to eq(16000)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(2973.95)
  end
end
