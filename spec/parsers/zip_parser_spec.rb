require 'spec_helper'

describe FormatParser::ZIPParser do
  it 'parses a ZIP archive with Zip64 extra fields (due to the number of files)' do
    fixture_path = fixtures_dir + '/ZIP/arch_many_entries.zip'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    expect(result).not_to be_nil

    expect(result.format).to eq(:zip)
    expect(result.nature).to eq(:archive)
    expect(result.entries.length).to eq(0xFFFF + 1)

    entry = result.entries.fetch(5674)
    expect(entry.type).to eq(:file)
    expect(entry.size).to eq(47)
    expect(entry.filename).to eq('file-0005674.txt')
  end

  it 'parses a ZIP archive with a few files' do
    fixture_path = fixtures_dir + '/ZIP/arch_few_entries.zip'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    expect(result).not_to be_nil

    expect(result.format).to eq(:zip)
    expect(result.nature).to eq(:archive)
    expect(result.entries.length).to eq(3)
  end

  it 'correctly identifies an empty directory' do
    fixture_path = fixtures_dir + '/ZIP/arch_with_empty_dir.zip'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    expect(result).not_to be_nil

    expect(result.format).to eq(:zip)
    expect(result.nature).to eq(:archive)
    expect(result.entries.length).to eq(3)

    dir_entry = result.entries.last
    expect(dir_entry.filename).to eq('папочка/')
    expect(dir_entry.type).to eq(:directory)
  end

  it 'correctly identifies Word documents' do
    fixture_path = fixtures_dir + '/ZIP/10.docx'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    expect(result.nature).to eq(:document)
    expect(result.format).to eq(:docx)

    fixture_path = fixtures_dir + '/ZIP/sample-docx.docx'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    expect(result.nature).to eq(:document)
    expect(result.format).to eq(:docx)
  end

  it 'is able to handle specific fuzzed input' do
    r = Random.new(354)
    1024.times do
      random_blob = StringIO.new(r.bytes(512 * 1024))
      subject.call(random_blob) # If there is an error in one of the parsers the example will raise too
    end
  end

  it 'returns a result that has a usable JSON representation' do
    fixture_path = fixtures_dir + '/ZIP/arch_with_empty_dir.zip'
    fi_io = File.open(fixture_path, 'rb')

    result = subject.call(fi_io)
    json_repr = JSON.pretty_generate(result)

    json_parsed_repr = JSON.parse(json_repr, symbolize_names: true)
    expect(json_parsed_repr[:nature]).to eq('archive')
    expect(json_parsed_repr[:format]).to eq('zip')
    expect(json_parsed_repr[:entries]).to be_kind_of(Array)
    expect(json_parsed_repr[:entries].length).to eq(3)

    json_parsed_repr[:entries].each do |e|
      expect(e[:filename]).to be_kind_of(String)
      expect(e[:size]).to be_kind_of(Integer)
      expect(e[:type]).to be_kind_of(String)
    end
  end

  it 'parses filenames in ZIP encoded in a local DOS encoding' do
    spanish_zip_path = fixtures_dir + '/ZIP/broken_filename.zip'

    result = subject.call(File.open(spanish_zip_path, 'rb'))

    first_entry = result.entries.first
    expect(first_entry.filename).to eq('Li��nia Extreme//')
    expect(first_entry.type).to eq(:directory)
  end
end
