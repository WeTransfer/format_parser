require 'spec_helper'

describe FormatParser::OggParser do
  it 'parses an ogg file' do
    parse_result = subject.call(File.open(__dir__ + '/../fixtures/Ogg/vorbis.ogg', 'rb'))

    expect(parse_result.nature).to eq(:audio)
    expect(parse_result.format).to eq(:ogg)
    expect(parse_result.num_audio_channels).to eq(1)
    expect(parse_result.audio_sample_rate_hz).to eq(16000)
    expect(parse_result.media_duration_seconds).to be_within(0.01).of(2973.95)
  end

  it 'skips a file if it contains more than MAX_POSSIBLE_OGG_PAGE_SIZE bytes of garbage at the end' do
    parse_result = subject.call(File.open(__dir__ + '/../fixtures/Ogg/with_garbage_at_the_end.ogg', 'rb'))
    expect(parse_result).to be_nil
  end
end
