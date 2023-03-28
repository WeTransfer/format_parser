require 'spec_helper'

describe FormatParser::MOVParser do
  describe '#likely_match?' do
    %w[mov mOv moV Mov MOv MoV MOV moov qt].each do |e|
      context "with foo.#{e}" do
        it 'should return true' do
          expect(subject.likely_match?("foo.#{e}")).to eq(true)
        end
      end
    end

    ['', 'foo', 'mov', 'foomov', 'foo.mp4', 'foo.mov.bar'].each do |f|
      context "with #{f}" do
        it 'should return false' do
          expect(subject.likely_match?(f)).to eq(false)
        end
      end
    end
  end

  describe '#call' do
    context "when magic bytes are absent" do
      let(:io) do
        input = [0x10].pack('N') + 'ftyp' + 'foo ' + [0x1].pack('N')
        StringIO.new(input)
      end

      it 'should return nil' do
        expect(subject.call(io)).to be_nil
      end
    end

    Dir.glob(fixtures_dir + '/MOV/valid/**/*.*').sort.each do |path|
      context "for #{path}" do
        let(:result) { subject.call(File.open(path, 'rb')) }

        it 'should not be nil' do
          expect(result).not_to be_nil
        end

        it 'should have video nature' do
          expect(result.nature).to eq(:video)
        end

        it 'should have MOV video content type' do
          expect(result.content_type).to eq('video/quicktime')
        end

        it 'should have MOV video format' do
          expect(result.format).to eq(:mov)
        end

        it 'should have a non-zero height ' do
          expect(result.height_px).to be > 0
        end

        it 'should have a non-zero width' do
          expect(result.width_px).to be > 0
        end

        it 'should have a non-zero duration' do
          expect(result.media_duration_seconds).to be > 0
        end

        it 'should have a non-nil frame rate' do
          expect(result.frame_rate).not_to be_nil
        end

        it 'should have intrinsics' do
          expect(result.intrinsics).not_to be_nil
        end
      end
    end

    Dir.glob(fixtures_dir + '/MOV/invalid/**/*.*').sort.each do |path|
      context "for #{path}" do
        let(:result) { subject.call(File.open(path, 'rb')) }

        it 'should be nil' do
          expect(result).to be_nil
        end
      end
    end

    context "for a standard MOV video" do
      let(:result) do
        path = fixtures_dir + '/MOV/valid/standard.mov'
        subject.call(File.open(path, 'rb'))
      end

      it 'should have the correct height' do
        expect(result.height_px).to eq(360)
      end

      it 'should have the correct width' do
        expect(result.width_px).to eq(640)
      end

      it 'should have the correct duration' do
        expect(result.media_duration_seconds.truncate(2)).to eq(9.36)
      end

      it 'should have the correct frame rate' do
        expect(result.frame_rate).to eq(30)
      end
    end

    context "for a scaled MOV video" do
      let(:result) do
        path = fixtures_dir + '/MOV/valid/scaled.mov'
        subject.call(File.open(path, 'rb'))
      end

      it 'should have the correct height' do
        expect(result.height_px).to eq(720)
      end

      it 'should have the correct width' do
        expect(result.width_px).to eq(1280)
      end
    end

    context "for a rotated MOV video" do
      let(:result) do
        path = fixtures_dir + '/MOV/valid/rotated.mov'
        subject.call(File.open(path, 'rb'))
      end

      it 'should have the correct height' do
        expect(result.height_px).to eq(640)
      end

      it 'should have the correct width' do
        expect(result.width_px).to eq(360)
      end
    end
  end
end
