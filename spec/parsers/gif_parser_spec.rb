require 'spec_helper'

describe FormatParser::GIFParser do
  describe 'is able to parse all the examples from FastImage' do
    Dir.glob(fixtures_dir + '/*.gif').each do |gif_path|
      it "is able to parse #{File.basename(gif_path)}" do
        parsed = subject.call(File.open(gif_path, 'rb'))

        expect(parsed).not_to be_nil

        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:gif)
        expect(parsed.color_mode).to eq(:indexed)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.width_px).to be > 0

        expect(parsed.height_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be > 0
      end
    end
  end

  describe 'is able to correctly parse our own examples' do
    it 'is able to parse the animated GIF' do
      gif_path = fixtures_dir + "GIF/anim.gif"

      parsed = subject.call(File.open(gif_path, 'rb'))
      expect(parsed).not_to be_nil

      expect(parsed.width_px).to eq(320)
      expect(parsed.height_px).to eq(180)
    end
  end
end
