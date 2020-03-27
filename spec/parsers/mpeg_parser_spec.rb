require 'spec_helper'

describe FormatParser::MPEGParser do
  it 'parses a first example mpg file' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MPG/video1.mpg', 'rb'))

    expect(parse_result.nature).to eq(:video)
    expect(parse_result.format).to eq(:mpg)
    expect(parse_result.width_px).to eq(560)
    expect(parse_result.height_px).to eq(320)
    expect(parse_result.intrinsics[:aspect_ratio]).to eq('1:1')
    expect(parse_result.intrinsics[:frame_rate]).to eq('30')
  end

  it 'parses a file with mpeg extension' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MPG/video2.mpeg', 'rb'))

    expect(parse_result.nature).to eq(:video)
    expect(parse_result.format).to eq(:mpg)
    expect(parse_result.width_px).to eq(720)
    expect(parse_result.height_px).to eq(480)
    expect(parse_result.intrinsics[:aspect_ratio]).to eq('4:3')
    expect(parse_result.intrinsics[:frame_rate]).to eq('29.97')
  end

  it 'parses a second example mpg file' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MPG/video3.mpg', 'rb'))

    expect(parse_result.nature).to eq(:video)
    expect(parse_result.format).to eq(:mpg)
    expect(parse_result.width_px).to eq(720)
    expect(parse_result.height_px).to eq(496)
    expect(parse_result.intrinsics[:aspect_ratio]).to eq('4:3')
    expect(parse_result.intrinsics[:frame_rate]).to eq('29.97')
  end

  it 'parses a bigger mpg file' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MPG/video4.mpg', 'rb'))

    expect(parse_result.nature).to eq(:video)
    expect(parse_result.format).to eq(:mpg)
    expect(parse_result.width_px).to eq(1920)
    expect(parse_result.height_px).to eq(1080)
    expect(parse_result.intrinsics[:aspect_ratio]).to eq('16:9')
    expect(parse_result.intrinsics[:frame_rate]).to eq('29.97')
  end

  it 'parses a file with different malformed first sequence header' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MPG/video5.mpg', 'rb'))

    expect(parse_result.nature).to eq(:video)
    expect(parse_result.format).to eq(:mpg)
    expect(parse_result.width_px).to eq(1440)
    expect(parse_result.height_px).to eq(1080)
    expect(parse_result.intrinsics[:aspect_ratio]).to eq('16:9')
    expect(parse_result.intrinsics[:frame_rate]).to eq('25')
  end

  it 'parses a MP4 file' do
    parse_result = described_class.call(File.open(__dir__ + '/../fixtures/MOOV/MP4/bmff.mp4', 'rb'))

    expect(parse_result).to be_nil
  end
end
