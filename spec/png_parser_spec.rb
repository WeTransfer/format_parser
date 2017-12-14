require 'spec_helper'

describe FormatParser::PNGParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(__dir__ + '/fixtures/*.png').each do |png_path|
      it "is able to parse #{File.basename(png_path)}" do
        parsed = subject.information_from_io(File.open(png_path, 'rb'))
        expect(parsed).not_to be_nil
        expect(parsed.file_nature).to eq(:image)
        expect(parsed.file_type).to eq(:png)
        expect(parsed.color_mode).to eq(:indexed)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end
  
  it 'is able to parse an animated PNG' do
    gif_path = __dir__ + "/fixtures/PNG/anim.png"

    parsed = subject.information_from_io(File.open(gif_path, 'rb'))
    expect(parsed).not_to be_nil

    expect(parsed.width_px).to eq(320)
    expect(parsed.height_px).to eq(180)
    expect(parsed.has_multiple_frames).to eq(true)
    expect(parsed.num_animation_or_video_frames).to eq(17)
  end
end
