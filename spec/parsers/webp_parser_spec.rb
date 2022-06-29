require 'spec_helper'

describe FormatParser::WebpParser do
  it 'does not parse files with an invalid RIFF header' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/invalid-header.webp', 'rb'))
    check_result(result, false)
  end

  it 'does not parse files with an unrecognised variant' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/unrecognised-variant.webp', 'rb'))
    check_result(result, false)
  end

  it 'successfully parses lossy (VP8) WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossy.webp', 'rb'))
    check_result(result, true, 181, 65)
  end

  it 'successfully parses lossless WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossless.webp', 'rb'))
    check_result(result, true, 181, 65)
  end

  it 'successfully parses lossless WebP files with an alpha channel' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossy.webp', 'rb'))
    check_result(result, true, 181, 65, has_transparency: true)
  end

  it 'successfully parses extended WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended.webp', 'rb'))
    check_result(result, true, 181, 65)
  end

  it 'successfully parses extended WebP files with an alpha channel' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-alpha.webp', 'rb'))
    check_result(result, true, 181, 65, has_transparency: true)
  end

  it 'successfully parses extended WebP files with animation' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-animation.webp', 'rb'))
    check_result(result, true, nil, nil, has_multiple_frames: true)
  end

  private

  def check_result(
    result,
    success,
    height_px = nil,
    width_px = nil,
    has_multiple_frames = false,
    has_transparency = false
  )
    if success
      expect(result).not_to be_nil
      expect(result.content_type).to eq('image/webp')
      expect(result.format).to eq(:webp)
      expect(result.has_multiple_frames).to eq(has_multiple_frames)
      expect(result.has_transparency).to eq(has_transparency)
      expect(result.height_px).to eq(height_px)
      expect(result.width_px).to eq(width_px)
    else
      expect(result).to be_nil
    end
  end
end
