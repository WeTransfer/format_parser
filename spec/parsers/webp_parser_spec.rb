require 'spec_helper'

describe FormatParser::WebpParser do
  it 'does not parse files with an invalid RIFF header' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/invalid-header.webp', 'rb'))
    expect(result).to be_nil
  end

  it 'does not parse files with an unrecognised variant' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/unrecognised-variant.webp', 'rb'))
    expect(result).to be_nil
  end

  it 'successfully parses lossy (VP8) WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossy.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses lossless WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossless.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses lossless WebP files with an alpha channel' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/lossless-alpha.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(true)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses extended WebP files' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses extended WebP files with an alpha channel' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-alpha.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(true)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses extended WebP files with Exif metadata' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-exif.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).not_to be_nil
    expect(result.intrinsics[:exif]).not_to be_nil
    expect(result.intrinsics[:exif].image_length).to eq(result.height_px)
    expect(result.intrinsics[:exif].image_width).to eq(result.width_px)
    expect(result.orientation).to eq(:top_left)
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses extended WebP files with XMP metadata' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-xmp.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).not_to be_nil
    expect(result.intrinsics[:xmp]).not_to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end

  it 'successfully parses extended WebP files with animation' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-animation.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(true)
    expect(result.has_transparency).to eq(true)
    expect(result.height_px).to eq(211)
    expect(result.intrinsics).to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(211)
  end

  it 'successfully skips malformed Exif chunks' do
    result = subject.call(File.open(fixtures_dir + 'WEBP/extended-malformed-exif.webp', 'rb'))
    expect(result).not_to be_nil
    expect(result.content_type).to eq('image/webp')
    expect(result.format).to eq(:webp)
    expect(result.has_multiple_frames).to eq(false)
    expect(result.has_transparency).to eq(false)
    expect(result.height_px).to eq(181)
    expect(result.intrinsics).not_to be_nil
    expect(result.intrinsics[:exif]).to be_nil
    expect(result.intrinsics[:xmp]).not_to be_nil
    expect(result.orientation).to be_nil
    expect(result.width_px).to eq(65)
  end
end
