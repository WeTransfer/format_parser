require 'spec_helper'

describe FormatParser::MP3Parser do
  it 'decodes and estimates duration for a VBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_vbr.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.836)
  end

  it 'reads the Xing header without raising errors' do
    fpath = fixtures_dir + '/MP3/test_xing_header.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.content_type).to eq('audio/mpeg')
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(48000)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.0342)
  end

  it 'does not misdetect a PNG' do
    fpath = fixtures_dir + '/PNG/anim.png'
    parsed = subject.call(File.open(fpath, 'rb'))
    expect(parsed).to be_nil
  end

  it 'does not misdetect a WAV' do
    fpath = fixtures_dir + '/WAV/c_SCAM_MIC_SOL001_RUN001.wav'
    parsed = subject.call(File.open(fpath, 'rb'))
    expect(parsed).to be_nil
  end

  describe 'title/artist/album attributes' do
    let(:parsed) { subject.call(File.open(fpath, 'rb')) }

    context 'when exist in id3 tags' do
      let(:fpath) { fixtures_dir + '/MP3/Cassy.mp3' }

      it 'set the attributes' do
        expect(parsed.artist).to eq('WeTransfer Studios/GIlles Peterson')
        expect(parsed.title).to eq('Cassy')
        expect(parsed.album).to eq('The Psychology of DJing')
      end
    end

    context 'when do not exist in id3 tags' do
      let(:fpath) { fixtures_dir + '/MP3/atc_fixture_vbr.mp3' }

      it 'set attributes with nil' do
        expect(parsed.title).to be_nil
        expect(parsed.artist).to be_nil
        expect(parsed.album).to be_nil
      end
    end

    context 'when has an empty tag' do
      let(:fpath) { fixtures_dir + '/MP3/id3v2_with_empty_tag.mp3' }

      it 'ignores the empty tags' do
        expect(parsed.intrinsics[:genre]).to eq('Rock')
      end
    end
  end

  it 'decodes and estimates duration for a CBR MP3' do
    fpath = fixtures_dir + '/MP3/atc_fixture_cbr.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.intrinsics).not_to be_nil
    expect(parsed.media_duration_seconds).to be_within(0.1).of(0.81)
  end

  it 'does not attempt to read ID3V2 tags that are too large' do
    more_bytes_than_permitted = 3 * 1024 * 1024
    gunk = Random.new.bytes(more_bytes_than_permitted)

    large_syncsfe_size = [ID3Tag::SynchsafeInteger.encode(more_bytes_than_permitted)].pack('N')
    prepped = StringIO.new(
      'ID3' + "\x03\x00".b + "\x00".b + large_syncsfe_size + gunk
    )

    expect(ID3Tag).not_to receive(:read)

    prepped.seek(0)
    result = FormatParser::MP3Parser::ID3Extraction.attempt_id3_v2_extraction(prepped)

    expect(result).to be_nil
    expect(prepped.pos).to eq(3145738)
  end

  it 'does not raise error when a tag frame has unsupported encoding' do
    fpath = fixtures_dir + '/MP3/id3v2_frame_with_invalid_encoding.mp3'

    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed.nature). to eq(:audio)
    expect(parsed.album).to eq('wetransfer')
    expect(parsed.artist).to eq('wetransfer')
    expect(parsed.title).to eq('test')
  end

  it 'reads the mpeg frames correctly' do
    fpath = fixtures_dir + '/MP3/test_read_frames.mp3'

    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed.audio_sample_rate_hz). to eq(48000)
  end

  it 'parses the Cassy MP3' do
    fpath = fixtures_dir + '/MP3/Cassy.mp3'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.num_audio_channels).to eq(2)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
    expect(parsed.media_duration_seconds).to be_within(0.1).of(1098.03)

    expect(parsed.intrinsics).not_to be_nil

    i = parsed.intrinsics
    expect(i[:artist]).to eq('WeTransfer Studios/GIlles Peterson')
    expect(i[:title]).to eq('Cassy')
    expect(i[:album]).to eq('The Psychology of DJing')
    expect(i[:comments]).to eq('0')
    expect(i[:id3tags]).not_to be_nil

    expect(parsed.intrinsics).not_to be_nil

    # Make sure we are good with our JSON representation as well
    JSON.pretty_generate(parsed)
  end

  it 'avoids returning a result when the parsed duration is infinite' do
    fpath = fixtures_dir + '/JPEG/too_many_APP1_markers_surrogate.jpg'
    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).to be_nil
  end

  it 'terminates early with an IOUtils error when the file is too small' do
    expect {
      subject.call(StringIO.new(''))
    }.to raise_error(FormatParser::IOUtils::InvalidRead)
  end

  it 'supports id3 v2.4.x' do
    fpath = fixtures_dir + '/MP3/id3v24.mp3'

    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed.artist). to eq('wetransfer')
  end

  it 'does not skip the first bytes if it is not a id3 tag header' do
    fpath = fixtures_dir + '/MP3/no_id3_tags.mp3'

    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).not_to be_nil

    expect(parsed.nature).to eq(:audio)
    expect(parsed.format).to eq(:mp3)
    expect(parsed.audio_sample_rate_hz).to eq(44100)
  end

  describe '#as_json' do
    it 'converts all hash keys to string when stringify_keys: true' do
      fpath = fixtures_dir + '/MP3/Cassy.mp3'
      result = subject.call(File.open(fpath, 'rb')).as_json(stringify_keys: true)

      expect(
        result['intrinsics'].keys.map(&:class).uniq
      ).to eq([String])

      expect(
        result['intrinsics']['id3tags'].map(&:class).uniq
      ).to eq([ID3Tag::Tag])
    end

    it 'does not convert the hash keys to string when stringify_keys: false' do
      fpath = fixtures_dir + '/MP3/Cassy.mp3'
      result = subject.call(File.open(fpath, 'rb')).as_json

      expect(
        result['intrinsics'].keys.map(&:class).uniq
      ).to eq([Symbol])

      expect(
        result['intrinsics'][:id3tags].map(&:class).uniq
      ).to eq([ID3Tag::Tag])
    end
  end

  it 'does not recognize TIFF files as MP3' do
    fpath = fixtures_dir + '/TIFF/test2.tif'

    parsed = subject.call(File.open(fpath, 'rb'))

    expect(parsed).to be_nil
  end
end
