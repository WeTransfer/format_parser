require 'spec_helper'

describe FormatParser::DPXParser do
  Dir.glob(fixtures_dir + '/dpx/*.*').each do |dpx_path|
    it "is able to parse #{File.basename(dpx_path)}" do
      parsed = subject.call(File.open(dpx_path, 'rb'))

      expect(parsed).not_to be_nil
      expect(parsed.nature).to eq(:image)
      expect(parsed.format).to eq(:dpx)

      # If we have an error in the struct offsets these values are likely to become
      # the maximum value of a 4-byte uint, which is way higher
      expect(parsed.width_px).to be_kind_of(Integer)
      expect(parsed.width_px).to be_between(0, 2048)
      expect(parsed.height_px).to be_kind_of(Integer)
      expect(parsed.height_px).to be_between(0, 4000)
    end
  end

  it 'correctly reads display dimensions corrected for the pixel aspect from the DPX header' do
    fi = File.open(fixtures_dir + '/dpx/aspect_237_example.dpx', 'rb')
    parsed = subject.call(fi)

    expect(parsed.width_px).to eq(1920)
    expect(parsed.height_px).to eq(1080)

    expect(parsed.display_width_px).to eq(1920)
    expect(parsed.display_height_px).to eq(810)

    expect(parsed.display_width_px / parsed.display_height_px.to_f).to be_within(0.01).of(2.37)
  end

  it 'does not explode on invalid inputs' do
    invalid = StringIO.new('SDPX' + (' ' * 64))
    expect {
      subject.call(invalid)
    }.to raise_error(FormatParser::IOUtils::InvalidRead)
  end
end
