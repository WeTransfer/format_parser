require 'spec_helper'

describe FormatParser::MP4Parser do
  describe '#likely_match?' do
    %w[mp4 mP4 Mp4 MP4 m4a m4b m4p m4r m4v].each do |e|
      context "with foo.#{e}" do
        it 'should return true' do
          expect(subject.likely_match?("foo.#{e}")).to eq(true)
        end
      end
    end

    ['', 'foo', 'mp4', 'foomp4', 'foo.mp3', 'foo.mov', 'foo.mp4.bar'].each do |f|
      context "with #{f}" do
        it 'should return false' do
          expect(subject.likely_match?(f)).to eq(false)
        end
      end
    end
  end

  describe '#call' do
    context "when the magic bytes aren't present" do
      let(:io) do
        input = [0x10].pack('N') + 'ftyp' + 'foo ' + [0x1].pack('N')
        StringIO.new(input)
      end

      it 'should return nil' do
        expect(subject.call(io)).to be_nil
      end
    end
  end
end
