require 'spec_helper'
require 'shellwords'

describe '/exe/format_parser_inspect binary' do
  let(:bin_path) do
    Shellwords.escape(File.expand_path(__dir__ + '/../exe/format_parser_inspect'))
  end

  it 'performs parsing on full default' do
    fixture_path = fixtures_dir + 'JPEG/divergent_pixel_dimensions_exif.jpg'

    result = `#{bin_path} #{Shellwords.escape(fixture_path)}`

    retval = JSON.parse(result, symbolize_names: true)
    parsed_result = retval.first
    expect(parsed_result[:source_path_or_url]).to end_with('divergent_pixel_dimensions_exif.jpg')
    expect(parsed_result[:options][:results]).to eq('first')
    expect(parsed_result[:result]).not_to be_nil
  end

  it 'performs parsing with --all' do
    fixture_path = fixtures_dir + 'JPEG/divergent_pixel_dimensions_exif.jpg'

    result = `#{bin_path} --all #{Shellwords.escape(fixture_path)}`

    retval = JSON.parse(result, symbolize_names: true)
    parsed_result = retval.first
    expect(parsed_result[:source_path_or_url]).to end_with('divergent_pixel_dimensions_exif.jpg')
    expect(parsed_result[:options][:results]).to eq('all')
    expect(parsed_result[:ambiguous]).to eq(false)
    expect(parsed_result[:results]).not_to be_empty
  end

  it 'performs parsing with --natures option' do
    fixture_path = fixtures_dir + 'JPEG/divergent_pixel_dimensions_exif.jpg'

    result = `#{bin_path} --natures=IMAGE #{Shellwords.escape(fixture_path)}`

    retval = JSON.parse(result, symbolize_names: true)
    parsed_result = retval.first
    expect(parsed_result[:source_path_or_url]).to end_with('divergent_pixel_dimensions_exif.jpg')
    expect(parsed_result[:options][:natures]).to eq(['image'])
    expect(parsed_result[:result]).not_to be_nil
  end

  it 'performs parsing with --formats option' do
    fixture_path = fixtures_dir + 'JPEG/divergent_pixel_dimensions_exif.jpg'

    result = `#{bin_path} --formats=zip #{Shellwords.escape(fixture_path)}`

    retval = JSON.parse(result, symbolize_names: true)
    parsed_result = retval.first
    expect(parsed_result[:source_path_or_url]).to end_with('divergent_pixel_dimensions_exif.jpg')
    expect(parsed_result[:options][:formats]).to eq(['zip'])
    expect(parsed_result[:result]).to be_nil
  end
end
