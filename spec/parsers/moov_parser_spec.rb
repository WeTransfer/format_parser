
require 'spec_helper'

describe FormatParser::MOOVParser do
  def deep_print_atoms(atoms, output, swimlanes = [])
    return unless atoms

    mid = '├'
    last = '└'
    horz = '─'
    vert = '│'
    cdn = '┬'
    n_atoms = atoms.length

    atoms.each_with_index do |atom, i|
      is_last_child = i == (n_atoms - 1)
      has_children = atom.children && atom.children.any?
      connector = is_last_child ? last : mid
      connector_down = has_children ? cdn : horz
      connector_left = is_last_child ? ' ' : vert

      output << swimlanes.join << connector << connector_down << horz << atom.to_s << "\n"
      if af = atom.atom_fields
        af.each do |(field, value)|
          output << swimlanes.join << connector_left << ('   %s: %s' % [field, value.inspect]) << "\n"
        end
      end
      deep_print_atoms(atom.children, output, swimlanes + [connector_left])
    end
  end

  Dir.glob(fixtures_dir + '/MOOV/**/*.m4a').sort.each do |m4a_path|
    it "is able to parse #{File.basename(m4a_path)}" do
      result = subject.call(File.open(m4a_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:audio)
      expect(result.media_duration_seconds).to be_kind_of(Float)
      expect(result.media_duration_seconds).to be > 0
      expect(result.content_type).to be_kind_of(String)
      expect(result.intrinsics).not_to be_nil
    end
  end

  Dir.glob(fixtures_dir + '/MOOV/**/*.mov').sort.each do |mov_path|
    it "is able to parse #{File.basename(mov_path)}" do
      result = subject.call(File.open(mov_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:video)
      expect(result.width_px).to be > 0
      expect(result.height_px).to be > 0
      expect(result.media_duration_seconds).to be_kind_of(Float)
      expect(result.media_duration_seconds).to be > 0
      expect(result.content_type).to eq('video/mp4')

      expect(result.intrinsics).not_to be_nil
    end
  end

  Dir.glob(fixtures_dir + '/MOOV/**/*.mp4').sort.each do |mp4_path|
    it "is able to parse #{File.basename(mp4_path)}" do
      result = subject.call(File.open(mp4_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:video)
      expect(result.width_px).to be > 0
      expect(result.height_px).to be > 0
      expect(result.media_duration_seconds).to be_kind_of(Float)
      expect(result.media_duration_seconds).to be > 0
      expect(result.content_type).to eq('video/mp4')

      expect(result.intrinsics).not_to be_nil
    end
  end

  it 'parses an M4A file and provides the necessary metadata' do
    m4a_path = fixtures_dir + '/MOOV/M4A/fixture.m4a'

    result = subject.call(File.open(m4a_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.nature).to eq(:audio)
    expect(result.format).to eq(:m4a)
    expect(result.content_type).to eq('audio/mp4')
  end

  it 'parses a MOV file and provides the necessary metadata' do
    mov_path = fixtures_dir + '/MOOV/MOV/Test_Circular_ProRes422.mov'

    result = subject.call(File.open(mov_path, 'rb'))

    expect(result).not_to be_nil
    expect(result.nature).to eq(:video)
    expect(result.format).to eq(:mov)
    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1080)
    expect(result.codecs).to eq(['apcn'])
  end

  it 'parses an MP4 video file and provides the necessary metadata' do
    mov_path = fixtures_dir + '/MOOV/MP4/bmff.mp4'

    result = subject.call(File.open(mov_path, 'rb'))

    expect(result).not_to be_nil
    expect(result.nature).to eq(:video)
    expect(result.format).to eq(:mov)
    expect(result.width_px).to eq(160)
    expect(result.height_px).to eq(90)
    expect(result.frame_rate).to eq(14.98)
    expect(result.codecs).to eq(['avc1'])
  end

  it 'provides filename hints' do
    expect(subject).to be_likely_match('file.m4v')
  end

  it 'reads correctly the video dimensions' do
    mov_path = fixtures_dir + '/MOOV/MOV/Test_Dimensions.mov'

    result = subject.call(File.open(mov_path, 'rb'))

    expect(result).not_to be_nil
    expect(result.nature).to eq(:video)
    expect(result.format).to eq(:mov)
    expect(result.width_px).to eq(640)
    expect(result.height_px).to eq(360)
    expect(result.frame_rate).to eq(30)
  end

  it 'does not raise error when a meta atom has size 0' do
    mov_path = fixtures_dir + '/MOOV/MOV/Test_Meta_Atom_With_Size_Zero.mov'

    result = subject.call(File.open(mov_path, 'rb'))
    expect(result).not_to be_nil
    expect(result.format).to eq(:mov)
  end

  it 'does not parse CR3 files' do
    cr3_path = fixtures_dir + '/CR3/Canon EOS R10 (RAW).CR3'
    result = subject.call(File.open(cr3_path, 'rb'))
    expect(result).to be_nil
  end
end
