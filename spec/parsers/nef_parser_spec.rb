require "spec_helper"

describe FormatParser::NEFParser do
  describe "Sample files from rawsamples" do
    Dir.glob(fixtures_dir + "/NEF/*.nef").each do |file_path|
      it "is able to parse #{File.basename(file_path)}" do
        parsed = subject.call(File.open(file_path, "rb"))

        expect(parsed).not_to be_nil
        expect(parsed.nature).to eq(:image)
        expect(parsed.format).to eq(:nef)

        expect(parsed.width_px).to be_kind_of(Integer)
        expect(parsed.height_px).to be_kind_of(Integer)

        expect(parsed.display_width_px).to be_kind_of(Integer)
        expect(parsed.display_height_px).to be_kind_of(Integer)

        expect(parsed.orientation).to be_kind_of(Symbol)

        expect(parsed.intrinsics[:exif]).not_to be_nil
      end
    end
  end

  describe "Image Dimensions" do
    it "parses dimensions properly for a given fixture" do
      # The default parser from EXIFr returns the dimensions from the embedded
      # thumbnails as being the image's actual dimensions.
      # We make sure we properly deal this.

      parsed = subject.call(File.open("#{fixtures_dir}/NEF/RAW_NIKON_1S2.NEF", "rb"))

      # Raw Image dimensions
      expect(parsed.width_px).to eq(4_608)
      expect(parsed.height_px).to eq(3_080)

      expect(parsed.orientation).to eq(:right_top)
    end

    it "correctly adjusts display dimensions for rotated images" do

      # This image is rotated, meaning display_width and display_height
      # should hold swapped values from width and height
      parsed = subject.call(File.open("#{fixtures_dir}/NEF/RAW_NIKON_1S2.NEF", "rb"))

      # Raw Image dimensions
      expect(parsed.width_px).to eq(4_608)
      expect(parsed.height_px).to eq(3_080)

      # Raw Dimensions considering orientation
      expect(parsed.display_width_px).to eq(3_080)
      expect(parsed.display_height_px).to eq(4_608)

      expect(parsed.orientation).to eq(:right_top)
    end

    it "does not return dimensions from embedded previews" do
      Dir.glob(fixtures_dir + "/NEF/*.nef").each do |file_path|
        # By default, NEF files include 160x120 sub_ifds.
        # This dimensions cannot be considered by the parser.

        parsed = subject.call(File.open(file_path, "rb"))
        
        expect(parsed.width_px).not_to eq(160)
        expect(parsed.height_px).not_to eq(120)
      end
    end

    it "properly extracts dimensions when there are more than 2 subIFDs in the image" do

      # this file has 3 subIFDs, and the RAW image information is actually in the one in the middle.
      nef_path = "#{fixtures_dir}/NEF/RAW_NIKON_D800_14bit_FX_UNCOMPRESSED.NEF"

      parsed = subject.call(File.open(nef_path, "rb"))

      expect(parsed).not_to be_nil
      expect(parsed.width_px).to eq(7424)
      expect(parsed.height_px).to eq(4924)
      expect(parsed.orientation).to eq(:top_left)
    end

    describe "correctly extracts dimensions from various NEF flavors of the same file" do
      Dir.glob(fixtures_dir + "/NEF/RAW_NIKON_D800*.nef").each do |file_path|
        it "is able to parse #{File.basename(file_path)}" do
          parsed = subject.call(File.open(file_path, "rb"))

          expect(parsed).not_to be_nil
          expect(parsed.width_px).to eq(7424)
          expect(parsed.height_px).to eq(4924)
        end
      end
    end
  end

  describe "Parser Performance" do
    it "extracts dimensions from a very large NEF economically" do

      # this file has 77.3mb
      file_path = "#{fixtures_dir}/NEF/RAW_NIKON_D800_14bit_FX_UNCOMPRESSED.NEF"

      io = File.open(file_path, "rb")
      io_with_stats = FormatParser::ReadLimiter.new(io)

      parsed = subject.call(io_with_stats)

      expect(parsed).not_to be_nil
      expect(parsed.width_px).to eq(7424)
      expect(parsed.height_px).to eq(4924)

      expect(io_with_stats.reads).to be_within(4).of(12)
      expect(io_with_stats.seeks).to be_within(4).of(12)
      expect(io_with_stats.bytes).to be_within(1024).of(59000)
    end
  end
end
