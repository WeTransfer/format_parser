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
    expect(dir_entry.filename).to eq("папочка/")
    expect(dir_entry.type).to eq(:directory)
  end
end
