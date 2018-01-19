# coding: utf-8
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

  Dir.glob(fixtures_dir + '/MOOV/**/*.*').sort.each do |moov_path|
    it "is able to parse #{File.basename(moov_path)}" do
      result = subject.call(File.open(moov_path, 'rb'))

      expect(result).not_to be_nil
      expect(result.nature).to eq(:video)
      expect(result.width_px).to be > 0
      expect(result.height_px).to be > 0
      expect(result.media_duration_seconds).to be_kind_of(Float)
      expect(result.media_duration_seconds).to be > 0

      expect(result.intrinsics).not_to be_nil
    end
  end

  it 'parses an M4A file and provides the necessary metadata'

  it 'parses a MOV file and provides the necessary metadata' do
    mov_path = fixtures_dir + '/MOOV/MOV/Test_Circular_ProRes422.mov'

    result = subject.call(File.open(mov_path, 'rb'))

    expect(result).not_to be_nil
    expect(result.nature).to eq(:video)
    expect(result.format).to eq(:mov)
    expect(result.width_px).to eq(1920)
    expect(result.height_px).to eq(1080)
  end

  it 'parses an MP4 video file and provides the necessary metadata' do
    mov_path = fixtures_dir + '/MOOV/MP4/bmff.mp4'

    result = subject.call(File.open(mov_path, 'rb'))

    expect(result).not_to be_nil
    expect(result.nature).to eq(:video)
    expect(result.format).to eq(:mov)
    expect(result.width_px).to eq(160)
    expect(result.height_px).to eq(90)
  end
end
