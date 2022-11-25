require 'spec_helper'

describe FormatParser::ISOBaseMediaFileFormat::Decoder do
  context 'when build_atom_tree is called' do
    context 'with no io' do
      it 'raises an error' do
        expect { subject.build_atom_tree(0x0) }.to raise_error(/IO missing - supply a valid IO object/)
      end
    end

    context('with a max_read smaller than the length of the IO') do
      let(:io) do
        # moov
        # moov
        input = [0x8].pack('N') + 'moov' + [0x8].pack('N') + 'moov'
        StringIO.new(input)
      end

      it 'stops building the tree' do
        expect(subject.build_atom_tree(0x0, io).length).to eq(0)
        expect(io.pos).to eq(0)

        expect(subject.build_atom_tree(0x8, io).length).to eq(1)
        expect(io.pos).to eq(0x8)
        io.seek(0)

        expect(subject.build_atom_tree(0x10, io).length).to eq(2)
        expect(io.pos).to eq(0x10)
      end
    end

    context 'when parsing an unknown atom' do
      let(:io) do
        # foo
        # |-> moov
        input = [0x14].pack('N') + 'foo ' + [0x1].pack('N') + [0x8].pack('N') + 'moov'
        StringIO.new(input)
      end

      it 'parses only the type, position and size, and skips any fields and children' do
        result = subject.build_atom_tree(0xFF, io)
        expect(result.length).to eq(1)
        expect(io.pos).to eq(0x14)

        foo_atom = result[0]
        expect(foo_atom.type).to eq('foo ')
        expect(foo_atom.position).to eq(0)
        expect(foo_atom.size).to eq(0x14)
        expect(foo_atom.fields).to eq({})
        expect(foo_atom.children).to eq([])
      end
    end

    context 'when parsing a container atom' do
      let(:io) do
        # moov
        # |-> foo
        # |-> bar
        input = [0x18].pack('N') + 'moov' + [0x8].pack('N') + 'foo ' + [0x8].pack('N') + 'bar '
        StringIO.new(input)
      end

      it 'parses type, position, size and children' do
        result = subject.build_atom_tree(0xFF, io)
        expect(result.length).to eq(1)
        expect(io.pos).to eq(0x18)

        moov_atom = result[0]
        expect(moov_atom.type).to eq('moov')
        expect(moov_atom.position).to eq(0)
        expect(moov_atom.size).to eq(0x18)
        expect(moov_atom.fields).to eq({})
        expect(moov_atom.children.length).to eq(2)
      end
    end

    context 'when parsing an empty atom' do
      let(:io) do
        # nmhd
        # |-> foo
        input = [0x18].pack('N') + 'nmhd' + [0x1].pack('c') + 'fla' + [0x2].pack('N') + [0x8].pack('N') + 'foo '
        StringIO.new(input)
      end

      it 'parses type, position, size, version and flags, and skips any other fields or children' do
        result = subject.build_atom_tree(0xFF, io)
        expect(result.length).to eq(1)
        expect(io.pos).to eq(0x18)

        nmhd_atom = result[0]
        expect(nmhd_atom.type).to eq('nmhd')
        expect(nmhd_atom.position).to eq(0)
        expect(nmhd_atom.size).to eq(0x18)
        expect(nmhd_atom.fields).to include({
          version: 1,
          flags: 'fla'
        })
        expect(nmhd_atom.children).to eq([])
      end
    end

    context 'when parsing a uuid atom' do
      let(:usertype) { '90f7c66ec2db476b977461e796f0dd4b' }
      let(:io) do
        input = [0x20].pack('N') + 'uuid' + [usertype].pack('H*') + [0x8].pack('N') + 'foo '
        StringIO.new(input)
      end

      it 'parses type, position, size and usertype, and skips any other fields or children' do
        # uuid
        # |-> foo
        result = subject.build_atom_tree(0xFF, io)
        expect(result.length).to eq(1)
        expect(io.pos).to eq(0x20)

        nmhd_atom = result[0]
        expect(nmhd_atom.type).to eq('uuid')
        expect(nmhd_atom.position).to eq(0)
        expect(nmhd_atom.size).to eq(0x20)
        expect(nmhd_atom.fields).to include({
          usertype: usertype,
        })
        expect(nmhd_atom.children).to eq([])
      end
    end
  end
end

describe FormatParser::ISOBaseMediaFileFormat::Decoder::Atom do
  context 'when initialized' do
    context 'without fields and/or children' do
      subject { described_class.new('foo', 0, 0) }

      it 'sets them as an empty array/hash' do
        expect(subject.type).to eq('foo')
        expect(subject.position).to eq(0)
        expect(subject.size).to eq(0)
        expect(subject.fields).to eq({})
        expect(subject.children).to eq([])
      end
    end

    context 'with fields and/or children' do
      let(:fields) { { foo: 1, bar: 'bar' } }
      let(:children) { [described_class.new('bar', 0, 0)] }

      subject { described_class.new('foo', 0, 0, fields, children) }

      it 'sets them correctly' do
        expect(subject.type).to eq('foo')
        expect(subject.position).to eq(0)
        expect(subject.size).to eq(0)
        expect(subject.fields).to eq(fields)
        expect(subject.children).to eq(children)
      end
    end
  end

  context 'when find_first_descendent is called' do
    context 'with no children' do
      subject { described_class.new('root', 0, 0) }
      it 'returns nil' do
        expect(subject.find_first_descendent(%w[root foo])).to be_nil
      end
    end

    context 'with no descendents of the given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns nil' do
        expect(subject.find_first_descendent(%w[root qux])).to be_nil
      end
    end

    context 'with multiple descendents of the given type(s)' do
      let(:descendent) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent
          ]),
          described_class.new('bar', 0, 0),
        ])
      end

      it 'returns the first relevant descendent in order of appearance' do
        expect(subject.find_first_descendent(%w[bar])).to be(descendent)
      end
    end
  end

  context 'when select_descendents is called' do
    context 'with no children' do
      subject { described_class.new('root', 0, 0) }
      it 'returns an empty array' do
        expect(subject.select_descendents(%w[root foo])).to eq([])
      end
    end

    context 'with no descendents of the given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns an empty array' do
        expect(subject.select_descendents(%w[root qux])).to eq([])
      end
    end

    context 'with multiple descendents of the given type(s)' do
      let(:descendent_1) { described_class.new('bar', 0, 0) }
      let(:descendent_3) { described_class.new('bar', 20, 20) }
      let(:descendent_2) { described_class.new('baz', 10, 10, nil, [descendent_3]) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent_1
          ]),
          descendent_2,
        ])
      end

      it 'returns all relevant descendents' do
        expect(subject.select_descendents(%w[bar baz])).to match_array([descendent_1, descendent_2, descendent_3])
      end
    end
  end
end
