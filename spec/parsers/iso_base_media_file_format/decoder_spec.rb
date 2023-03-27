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
