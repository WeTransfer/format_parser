require 'spec_helper'

describe FormatParser::AdtsHeaderInfo do
  shared_examples "parsed header" do |header_bits, expected_mpeg_version_description, expected_protection_absence, expected_profile_description, expected_mpeg4_sampling_frequency, expected_mpeg4_channel_config, expected_number_of_audio_channels, expected_originality, expected_home_usage, expected_frame_length, expected_aac_frames_per_adts_frame, expected_has_fixed_bitrate|
    it "extracts correct values for header #{header_bits}" do
      result = FormatParser::AdtsHeaderInfo.parse_adts_header(header_bits.split(''))
      expect(result).not_to be_nil
      expect(result.mpeg_version_description).to eq(expected_mpeg_version_description)
      expect(result.protection_absence).to eq(expected_protection_absence)
      expect(result.profile_description).to eq(expected_profile_description)
      expect(result.mpeg4_sampling_frequency).to eq(expected_mpeg4_sampling_frequency)
      expect(result.mpeg4_channel_config).to eq(expected_mpeg4_channel_config)
      expect(result.number_of_audio_channels).to eq(expected_number_of_audio_channels)
      expect(result.originality).to eq(expected_originality)
      expect(result.home_usage).to eq(expected_home_usage)
      expect(result.frame_length).to eq(expected_frame_length)
      expect(result.aac_frames_per_adts_frame).to eq(expected_aac_frames_per_adts_frame)
      expect(result.has_fixed_bitrate?).to eq(expected_has_fixed_bitrate)
    end
  end

  shared_examples "invalid header" do |failure_reason, header_bits|
    it "fails on #{failure_reason} for header #{header_bits}" do
      result = FormatParser::AdtsHeaderInfo.parse_adts_header(header_bits.split(''))
      expect(result).to be_nil
    end
  end

  # These headers have been validated here: https://www.p23.nl/projects/aac-header/
  include_examples 'parsed header', '1111111111110001010111001000000000101110011111111111110000100001', 'MPEG-4', true, 'AAC_LC (Low Complexity)', 22050, 2, 2, false, false, 371, 1, false
  include_examples 'parsed header', '111111111111000101010000010000000000011110011111111111001101111000000010', 'MPEG-4', true, 'AAC_LC (Low Complexity)', 44100, 1, 1, false, false, 60, 1, false

  include_examples 'invalid header', 'invalid syncword', '1111110111110001010111001000000000101110011111111111110000100001'
  include_examples 'invalid header', 'invalid layer value', '1111111111110011010111001000000000101110011111111111110000100001'
  include_examples 'invalid header', 'invalid sampling frequency index 15', '1111111111110001011111001000000000101110011111111111110000100001'
  include_examples 'invalid header', 'zero frame length', '1111111111110001010111001000000000000000011111111111110000100001'
  include_examples 'invalid header', 'random header', '101000101011010101010101111010101010101011001010101010101111000000011101'
end
