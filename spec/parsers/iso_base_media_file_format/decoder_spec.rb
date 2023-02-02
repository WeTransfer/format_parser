require 'spec_helper'

describe FormatParser::ISOBaseMediaFileFormat::Decoder do
  describe '#build_box_tree' do
    context 'when IO not provided' do
      context 'when IO not previously provided' do
        it 'raises an error' do
          expect { subject.build_box_tree(0x0) }.to raise_error(/IO missing - supply a valid IO object/)
        end
      end

      context 'when IO previously provided' do
        let(:io) { StringIO.new('') }
        it 'does not raise an error' do
          expect(subject.build_box_tree(0x0, io)).to eq([])
          expect(subject.build_box_tree(0x0)).to eq([])
        end
      end
    end

    context 'when max_read smaller than IO length' do
      let(:io) do
        # moov
        # moov
        input = [0x8].pack('N') + 'moov' + [0x8].pack('N') + 'moov'
        StringIO.new(input)
      end

      it 'stops building the tree' do
        expect(subject.build_box_tree(0x0, io).length).to eq(0)
        expect(io.pos).to eq(0)

        expect(subject.build_box_tree(0x8, io).length).to eq(1)
        expect(io.pos).to eq(0x8)
        io.seek(0)

        expect(subject.build_box_tree(0x10, io).length).to eq(2)
        expect(io.pos).to eq(0x10)
      end
    end

    context 'when parsing unknown box' do
      let(:io) do
        # foo
        # |-> moov
        input = [0x14].pack('N') + 'foo ' + [0x1].pack('N') + [0x8].pack('N') + 'moov'
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it('parses successfully') { expect(result.length).to eq(1) }
      it('parses the correct type') { expect(result[0].type).to eq('foo ') }
      it('parses the correct position') { expect(result[0].position).to eq(0) }
      it('parses the correct size') { expect(result[0].size).to eq(0x14) }
      it('skips additional fields') { expect(result[0].fields).to eq({}) }
      it('skips children') { expect(result[0].children).to eq([]) }
    end

    context 'when parsing a container box' do
      let(:io) do
        # moov
        # |-> foo
        # |-> bar
        input = [0x18].pack('N') + 'moov' + [0x8].pack('N') + 'foo ' + [0x8].pack('N') + 'bar '
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it('parses successfully') { expect(result.length).to eq(1) }
      it('parses the correct type') { expect(result[0].type).to eq('moov') }
      it('parses the correct position') { expect(result[0].position).to eq(0) }
      it('parses the correct size') { expect(result[0].size).to eq(0x18) }
      it('skips additional fields') { expect(result[0].fields).to eq({}) }
      it('parses children') { expect(result[0].children.length).to eq(2) }
    end

    context 'when parsing an empty box' do
      let(:io) do
        # nmhd
        # |-> foo
        input = [0x18].pack('N') + 'nmhd' + [0x1].pack('c') + 'fla' + [0x2].pack('N') + [0x8].pack('N') + 'foo '
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it('parses successfully') { expect(result.length).to eq(1) }
      it('parses the correct type') { expect(result[0].type).to eq('nmhd') }
      it('parses the correct position') { expect(result[0].position).to eq(0) }
      it('parses the correct size') { expect(result[0].size).to eq(0x18) }
      it('parses version and flags') do
        expect(result[0].fields).to include({
          version: 1,
          flags: 'fla'
        })
      end
      it('skips children') { expect(result[0].children).to eq([]) }
    end

    context 'when parsing a uuid box' do
      let(:usertype) { '90f7c66ec2db476b977461e796f0dd4b' }
      let(:io) do
        # uuid
        # |-> foo
        input = [0x20].pack('N') + 'uuid' + [usertype].pack('H*') + [0x8].pack('N') + 'foo '
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it('parses successfully') { expect(result.length).to eq(1) }
      it('parses the correct type') { expect(result[0].type).to eq('uuid') }
      it('parses the correct position') { expect(result[0].position).to eq(0) }
      it('parses the correct size') { expect(result[0].size).to eq(0x20) }
      it('parses usertype') { expect(result[0].fields).to include({ usertype: usertype }) }
      it('skips children') { expect(result[0].children).to eq([]) }
    end
  end
end

describe FormatParser::ISOBaseMediaFileFormat::Decoder::Box do
  describe '.new' do
    context 'when no fields/children' do
      subject { described_class.new('foo', 0, 0) }

      it 'sets them as empty hash/array' do
        expect(subject.fields).to eq({})
        expect(subject.children).to eq([])
      end
    end

    context 'when fields/children' do
      let(:fields) { { foo: 1, bar: 'bar' } }
      let(:children) { [described_class.new('bar', 0, 0)] }

      subject { described_class.new('foo', 0, 0, fields, children) }

      it 'sets them correctly' do
        expect(subject.fields).to eq(fields)
        expect(subject.children).to eq(children)
      end
    end
  end

  describe '#find_first_descendent' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }
      it 'returns nil' do
        expect(subject.find_first_descendent(%w[root foo])).to be_nil
      end
    end

    context 'when no descendents of given type(s)' do
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

    context 'when multiple descendents of given type(s)' do
      let(:descendent) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent
          ]),
          described_class.new('bar', 0, 0),
        ])
      end

      it 'returns first matching descendent' do
        expect(subject.find_first_descendent(%w[bar])).to be(descendent)
      end
    end
  end

  describe '#include?' do
    context 'with symbol' do
      context 'when no fields' do
        subject { described_class.new('root', 0, 0) }

        it('returns false') { expect(subject.include?(:foo)).to eq(false) }
      end

      context 'when no matching field' do
        let(:fields) { { foo: 'bar' } }
        subject { described_class.new('root', 0, 0, fields) }

        it('returns false') { expect(subject.include?(:baz)).to eq(false) }
      end

      context 'when matching field' do
        let(:fields) { { foo: 'bar', baz: 'qux' } }
        subject { described_class.new('root', 0, 0, fields) }

        it('returns true') { expect(subject.include?(:baz)).to eq(true) }
      end
    end

    context 'with string' do
      context 'when no children' do
        subject do
          described_class.new('root', 0, 0)
        end

        it('returns false') { expect(subject.include?('foo')).to eq(false) }
      end

      context 'when no matching child' do
        subject do
          described_class.new('root', 0, 0, nil, [
            described_class.new('foo', 0, 0),
          ])
        end

        it('returns false') { expect(subject.include?('bar')).to eq(false) }
      end

      context 'when matching child' do
        subject do
          described_class.new('root', 0, 0, nil, [
            described_class.new('foo', 0, 0),
            described_class.new('bar', 0, 0)
          ])
        end

        it('returns false') { expect(subject.include?('bar')).to eq(false) }
      end
    end

    context 'with something else' do
      subject do
        described_class.new('root', 0, 0, { foo: 'bar' }, [
          described_class.new('foo', 0, 0),
        ])
      end

      it('returns false') { expect(subject.include?(0)).to eq(false) }
    end
  end

  describe '#select_descendents' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }
      it 'returns empty array' do
        expect(subject.select_descendents(%w[root foo])).to eq([])
      end
    end

    context 'when no descendents of given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns empty array' do
        expect(subject.select_descendents(%w[root qux])).to eq([])
      end
    end

    context 'when multiple descendents of given type(s)' do
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

      it 'returns all matching descendents' do
        expect(subject.select_descendents(%w[bar baz])).to match_array([descendent_1, descendent_2, descendent_3])
      end
    end
  end
end
