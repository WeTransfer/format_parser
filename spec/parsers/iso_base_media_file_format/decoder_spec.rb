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

      it 'parses successfully' do
        expect(result.length).to eq(1)
      end

      it 'parses the correct type' do
        expect(result[0].type).to eq('foo ')
      end

      it 'parses the correct position' do
        expect(result[0].position).to eq(0)
      end

      it 'parses the correct size' do
        expect(result[0].size).to eq(0x14)
      end

      it 'skips additional fields' do
        expect(result[0].fields).to eq({})
      end

      it 'skips children' do
        expect(result[0].children).to eq([])
      end
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

      it 'parses successfully' do
        expect(result.length).to eq(1)
      end

      it 'parses the correct type' do
        expect(result[0].type).to eq('moov')
      end

      it 'parses the correct position' do
        expect(result[0].position).to eq(0)
      end

      it 'parses the correct size' do
        expect(result[0].size).to eq(0x18)
      end

      it 'skips additional fields' do
        expect(result[0].fields).to eq({})
      end

      it 'parses children' do
        expect(result[0].children.length).to eq(2)
      end
    end

    context 'when parsing an empty box' do
      let(:io) do
        # nmhd
        # |-> foo
        input = [0x18].pack('N') + 'nmhd' + [0x1].pack('c') + 'fla' + [0x2].pack('N') + [0x8].pack('N') + 'foo '
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it 'parses successfully' do
        expect(result.length).to eq(1)
      end

      it 'parses the correct type' do
        expect(result[0].type).to eq('nmhd')
      end

      it 'parses the correct position' do
        expect(result[0].position).to eq(0)
      end

      it 'parses the correct size' do
        expect(result[0].size).to eq(0x18)
      end

      it 'parses version and flags' do
        expect(result[0].fields).to include({
          version: 1,
          flags: 'fla'
        })
      end

      it 'skips children' do
        expect(result[0].children).to eq([])
      end
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

      it 'parses successfully' do
        expect(result.length).to eq(1)
      end

      it 'parses the correct type' do
        expect(result[0].type).to eq('uuid')
      end

      it 'parses the correct position' do
        expect(result[0].position).to eq(0)
      end

      it 'parses the correct size' do
        expect(result[0].size).to eq(0x20)
      end

      it 'parses usertype' do
        expect(result[0].fields).to include({ usertype: usertype })
      end

      it 'skips children' do
        expect(result[0].children).to eq([])
      end
    end

    context 'when parsing a box with 0 size' do
      let(:io) do
        # foo
        # moov
        # |-> bar
        # |-> baz
        input = [0x8].pack('N') + 'foo ' + [0x0].pack('N') + 'moov' + [0x8].pack('N') + 'bar ' + [0x8].pack('N') + 'baz '
        StringIO.new(input)
      end
      let(:result) { subject.build_box_tree(0xFF, io) }

      it 'reads the rest of the file' do
        expect(result.length).to eq(2)
        expect(io.pos).to eq(0x20)
      end

      it 'parses correctly' do
        expect(result[0].type).to eq('foo ')
        expect(result[1].type).to eq('moov')
        expect(result[1].children.length).to eq(2)
        expect(result[1].children[0].type).to eq('bar ')
        expect(result[1].children[1].type).to eq('baz ')
      end
    end
  end
end
