require_relative '../spec_helper'

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
    context "when magic bytes are absent" do
      let(:io) do
        input = [0x10].pack('N') + 'ftyp' + 'foo ' + [0x1].pack('N')
        StringIO.new(input)
      end

      it 'should return nil' do
        expect(subject.call(io)).to be_nil
      end
    end

    Dir.glob(fixtures_dir + '/MP4/valid/video/*.*').sort.each do |path|
      context "for #{path}" do
        let(:result) { subject.call(File.open(path, 'rb')) }

        it('should not be nil') { expect(result).not_to be_nil }
        it('should have video nature') { expect(result.nature).to eq(:video) }
        it('should have MP4 video content type') { expect(result.content_type).to eq('video/mp4') }
        it('should have MP4 video format') { expect([:mp4, :mv4]).to include(result.format) }
        it('should have a non-zero height ') { expect(result.height_px).to be > 0 }
        it('should have a non-zero width') { expect(result.width_px).to be > 0 }
        it('should have a non-zero duration') { expect(result.media_duration_seconds).to be > 0 }
        it('should have a non-nil frame rate') { expect(result.frame_rate).not_to be_nil }
        it('should have intrinsics') { expect(result.intrinsics).not_to be_nil }
      end
    end

    Dir.glob(fixtures_dir + '/MP4/valid/audio/*.*').sort.each do |path|
      context "for #{path}" do
        let(:result) { subject.call(File.open(path, 'rb')) }

        it('should not be nil') { expect(result).not_to be_nil }
        it('should have audio nature') { expect(result.nature).to eq(:audio) }
        it('should have MP4 audio content type') { expect(result.content_type).to eq('audio/mp4') }
        it('should have MP4 audio format') { expect([:m4a, :m4b, :m4p, :m4r]).to include(result.format) }
        it('should have a non-zero duration') { expect(result.media_duration_seconds).to be > 0 }
        it('should have intrinsics') { expect(result.intrinsics).not_to be_nil }
      end
    end

    Dir.glob(fixtures_dir + '/MP4/invalid/**/*.*').sort.each do |path|
      context "for #{path}" do
        let(:result) { subject.call(File.open(path, 'rb')) }

        it('should be nil') { expect(result).to be_nil }
      end
    end

    context "for a standard MP4 video" do
      let(:result) do
        path = fixtures_dir + '/MP4/valid/video/standard.mp4'
        subject.call(File.open(path, 'rb'))
      end

      it('should have the correct height') { expect(result.height_px).to eq(360) }
      it('should have the correct width') { expect(result.width_px).to eq(640) }
      it('should have the correct duration') { expect(result.media_duration_seconds.truncate(2)).to eq(9.36) }
      it('should have the correct frame rate') { expect(result.frame_rate).to eq(30) }
    end

    context "for a scaled MP4 video" do
      let(:result) do
        path = fixtures_dir + '/MP4/valid/video/scaled.mp4'
        subject.call(File.open(path, 'rb'))
      end

      it('should have the correct height') { expect(result.height_px).to eq(720) }
      it('should have the correct width') { expect(result.width_px).to eq(1280) }
    end

    context "for a rotated MP4 video" do
      let(:result) do
        path = fixtures_dir + '/MP4/valid/video/rotated.mp4'
        subject.call(File.open(path, 'rb'))
      end

      it('should have the correct height') { expect(result.height_px).to eq(640) }
      it('should have the correct width') { expect(result.width_px).to eq(360) }
    end
  end
end
