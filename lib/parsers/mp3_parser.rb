require 'ks'
require 'id3tag'

class FormatParser::MP3Parser
  include FormatParser::IOUtils

  require_relative 'mp3_parser/id3_extraction'

  class MPEGFrame < Ks.strict(:offset_in_file, :mpeg_id, :channels, :sample_rate, :frame_length, :frame_bitrate)
  end

  class VBRHeader < Ks.strict(:frames, :byte_count, :toc_entries, :vbr_scale)
  end

  class MP3Info < Ks.strict(:duration_seconds, :num_channels, :sampling_rate)
  end

  class InvalidDeepFetch < KeyError
  end

  # We limit the number of MPEG frames we scan
  # to obtain our duration estimation
  MAX_FRAMES_TO_SCAN = 500

  # Default frame size for mp3
  SAMPLES_PER_FRAME = 1152

  # For some edge cases
  ZIP_LOCAL_ENTRY_SIGNATURE = "PK\x03\x04\x14\x00".b
  PNG_HEADER_BYTES = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')

  # Wraps the Tag object returned by ID3Tag in such
  # a way that a usable JSON representation gets
  # returned
  class TagWrapper < SimpleDelegator
    include FormatParser::AttributesJSON

    MEMBERS = [:artist, :title, :album, :year, :track_nr, :genre, :comments, :unsychronized_transcription]

    def self.new(wrapped)
      wrapped ? super : nil
    end

    def to_h
      tag = __getobj__
      MEMBERS.each_with_object({}) do |k, h|
        value = tag.public_send(k)
        h[k] = value if value && !value.empty?
      end
    end
  end

  def likely_match?(filename)
    filename =~ /\.mp3$/i
  end

  def call(raw_io)
    io = FormatParser::IOConstraint.new(raw_io)

    # Special case: some ZIPs (Office documents) did detect as MP3s.
    # To avoid having that happen, we check for the PKZIP signature -
    # local entry header signature - at the very start of the file.
    # If the file is too small safe_read will fail too and the parser
    # will terminate here. Same with PNGs. In the future
    # we should implement "confidence" for MP3 as of all our formats
    # it is by far the most lax.
    header = safe_read(io, 8)
    return if header.start_with?(ZIP_LOCAL_ENTRY_SIGNATURE)
    return if header.start_with?(PNG_HEADER_BYTES)

    # Read all the ID3 tags (or at least attempt to)
    io.seek(0)
    id3v1 = ID3Extraction.attempt_id3_v1_extraction(io)
    tags = [id3v1, ID3Extraction.attempt_id3_v2_extraction(io)].compact

    # Compute how many bytes are occupied by the actual MPEG frames
    ignore_bytes_at_tail = id3v1 ? 128 : 0
    ignore_bytes_at_head = io.pos
    bytes_used_by_frames = io.size - ignore_bytes_at_head - ignore_bytes_at_tail

    io.seek(ignore_bytes_at_head)

    maybe_xing_header, initial_frames = parse_mpeg_frames(io)

    return if initial_frames.empty?

    first_frame = initial_frames.first

    id3tags_hash = with_id3tag_local_configs { blend_id3_tags_into_hash(*tags) }

    file_info = FormatParser::Audio.new(
      format: :mp3,
      # media_duration_frames is omitted because the frames
      # in MPEG are not the same thing as in a movie file - they
      # do not tell anything of substance
      num_audio_channels: first_frame.channels,
      audio_sample_rate_hz: first_frame.sample_rate,
      intrinsics: id3tags_hash.merge(id3tags: tags)
    )

    extra_file_attirbutes = fetch_extra_attributes_from_id3_tags(id3tags_hash)

    extra_file_attirbutes.each do |name, value|
      file_info.send(:"#{name}=", value)
    end

    if maybe_xing_header
      duration = maybe_xing_header.frames * SAMPLES_PER_FRAME / first_frame.sample_rate.to_f
      _bit_rate = maybe_xing_header.byte_count * 8 / duration / 1000
      file_info.media_duration_seconds = duration
      return file_info
    end

    # Estimate duration using the frames we did parse - to have an exact one
    # we would need to have all the frames and thus read most of the file
    _avg_bitrate = float_average_over(initial_frames, :frame_bitrate)
    avg_frame_size = float_average_over(initial_frames, :frame_length)
    avg_sample_rate = float_average_over(initial_frames, :sample_rate)

    est_frame_count = bytes_used_by_frames / avg_frame_size
    est_samples = est_frame_count * SAMPLES_PER_FRAME
    est_duration_seconds = est_samples / avg_sample_rate

    # Safeguard for i.e. some JPEGs being recognized as MP3
    # to prevent ambiguous recognition
    return if est_duration_seconds == Float::INFINITY

    file_info.media_duration_seconds = est_duration_seconds
    file_info
  end

  private

  # The implementation of the MPEG frames parsing is mostly based on tinytag,
  # a sweet little Python library for parsing audio metadata - do check it out
  # if you have a minute. https://pypi.python.org/pypi/tinytag
  def parse_mpeg_frames(io)
    mpeg_frames = []
    bytes_to_read = 4

    MAX_FRAMES_TO_SCAN.times do |frame_i|
      # Read through until we can latch onto the 11 sync bits. Read in 4-byte
      # increments to save on read() calls
      data = io.read(bytes_to_read)

      # If we are at EOF - stop iterating
      break unless data && data.bytesize == bytes_to_read

      # Look for the sync pattern. It can be either the last byte being 0xFF,
      # or any of the 2 bytes in sequence being 0xFF and > 0xF0.
      four_bytes = data.unpack('C4')
      seek_jmp = sync_bytes_offset_in_4_byte_seq(four_bytes)
      if seek_jmp > 0
        io.seek(io.pos - bytes_to_read + seek_jmp)
        next
      end

      # Once we are past that stage we have latched onto a sync frame header
      sync, conf, bitrate_freq, rest = four_bytes
      frame_detail = parse_mpeg_frame_header(io.pos - bytes_to_read, sync, conf, bitrate_freq, rest)
      mpeg_frames << frame_detail

      # There might be a xing header in the first frame that contains
      # all the info we need, otherwise parse multiple frames to find the
      # accurate average bitrate
      if frame_i == 0
        frame_data_str = io.read(frame_detail.frame_length)
        io.seek(io.pos - frame_detail.frame_length)
        xing_header = attempt_xing_header(frame_data_str)
        if xing_header_usable_for_duration?(xing_header)
          return [xing_header, mpeg_frames]
        end
      end
      if frame_detail.frame_length > 1 # jump over current frame body
        io.seek(io.pos + frame_detail.frame_length - bytes_to_read)
      end
    end
    [nil, mpeg_frames]
  rescue InvalidDeepFetch # A frame was invalid - bail out since it's unlikely we can recover
    [nil, mpeg_frames]
  end

  def parse_mpeg_frame_header(offset_in_file, _sync, conf, bitrate_freq, rest)
    # see this page for the magic values used in mp3:
    # http:/www.mpgedit.org/mpgedit/mpeg_format/mpeghdr.htm
    samplerates = [
      [11025, 12000,  8000],  # MPEG 2.5
      [],                     # reserved
      [22050, 24000, 16000],  # MPEG 2
      [44100, 48000, 32000],  # MPEG 1
    ]
    v1l1 = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0]
    v1l2 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0]
    v1l3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
    v2l1 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0]
    v2l2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
    v2l3 = v2l2
    bitrate_by_version_by_layer = [
      [nil, v2l3, v2l2, v2l1],  # MPEG Version 2.5  # note that the layers go
      nil,                      # reserved          # from 3 to 1 by design.
      [nil, v2l3, v2l2, v2l1],  # MPEG Version 2    # the first layer id is
      [nil, v1l3, v1l2, v1l1],  # MPEG Version 1    # reserved
    ]

    channels_per_channel_mode = [
      2,  # 00 Stereo
      2,  # 01 Joint stereo (Stereo)
      2,  # 10 Dual channel (2 mono channels)
      1,  # 11 Single channel (Mono)
    ]

    br_id = (bitrate_freq >> 4) & 0x0F  # biterate id
    sr_id = (bitrate_freq >> 2) & 0x03  # sample rate id
    padding = bitrate_freq & 0x02 > 0 ? 1 : 0
    mpeg_id = (conf >> 3) & 0x03
    layer_id = (conf >> 1) & 0x03
    channel_mode = (rest >> 6) & 0x03
    channels = channels_per_channel_mode.fetch(channel_mode)
    sample_rate = deep_fetch(samplerates, mpeg_id, sr_id)
    frame_bitrate = deep_fetch(bitrate_by_version_by_layer, mpeg_id, layer_id, br_id)
    frame_length = (144_000 * frame_bitrate) / sample_rate + padding
    MPEGFrame.new(
      offset_in_file: offset_in_file,
      mpeg_id: mpeg_id,
      channels: channels,
      sample_rate: sample_rate,
      frame_length: frame_length,
      frame_bitrate: frame_bitrate,
    )
  end

  # Scan 4 byte values, and check whether there is
  # a pattern of the 11 set bits anywhere within it
  # or whether there is the 0xFF byte at the end
  def sync_bytes_offset_in_4_byte_seq(four_bytes)
    four_bytes[0...3].each_with_index do |byte, i|
      next_byte = four_bytes[i + 1]
      return i if byte == 0xFF && next_byte > 0xE0
    end
    four_bytes[-1] == 0xFF ? 3 : 4
  end

  def attempt_xing_header(frame_body)
    unless xing_offset = frame_body.index('Xing')
      return # No Xing in this frame
    end

    io = StringIO.new(frame_body)
    io.seek(xing_offset + 4) # Include the length of "Xing" itself

    # https://www.codeproject.com/Articles/8295/MPEG-Audio-Frame-Header#XINGHeader
    header_flags, _ = io.read(4).unpack('i>')
    frames = byte_count = toc = vbr_scale = nil

    frames = io.read(4).unpack('N1').first if header_flags & 1 != 0   # FRAMES FLAG

    byte_count = io.read(4).unpack('N1').first if header_flags & 2 != 0   # BYTES FLAG

    toc = io.read(100).unpack('C100') if header_flags & 4 != 0   # TOC FLAG

    vbr_scale = io.read(4).unpack('N1').first if header_flags & 8 != 0   # VBR SCALE FLAG

    VBRHeader.new(frames: frames, byte_count: byte_count, toc_entries: toc, vbr_scale: vbr_scale)
  end

  def average_bytes_and_bitrate(_mpeg_frames)
    avg_bytes_per_frame = initial_frames.map(&:frame_length).inject(&:+) / initial_frames.length.to_f
    avg_bitrate_per_frame = initial_frames.map(&:frame_bitrate).inject(&:+) / initial_frames.length.to_f
    [avg_bytes_per_frame, avg_bitrate_per_frame]
  end

  def xing_header_usable_for_duration?(xing_header)
    xing_header && xing_header.frames && xing_header.byte_count && xing_header.vbr_scale
  end

  def float_average_over(enum, property)
    enum.map(&property).inject(&:+) / enum.length.to_f
  end

  def deep_fetch(from, *keys)
    keys.inject(from) { |receiver, key_or_idx| receiver.fetch(key_or_idx) }
  rescue IndexError, NoMethodError
    raise InvalidDeepFetch, "Could not retrieve #{keys.inspect} from #{from.inspect}"
  end

  def blend_id3_tags_into_hash(*tags)
    tags.each_with_object({}) do |tag, h|
      h.merge!(TagWrapper.new(tag).to_h)
    end
  end

  def fetch_extra_attributes_from_id3_tags(id3tags_hash)
    attrs = {}

    attrs[:title] = FormatParser.string_to_lossy_utf8(id3tags_hash[:title]) unless id3tags_hash[:title].to_s.empty?
    attrs[:album] = FormatParser.string_to_lossy_utf8(id3tags_hash[:album]) unless id3tags_hash[:album].to_s.empty?
    attrs[:artist] = FormatParser.string_to_lossy_utf8(id3tags_hash[:artist]) unless id3tags_hash[:artist].to_s.empty?

    attrs
  end

  def with_id3tag_local_configs
    ID3Tag.local_configuration do |c|
      c.string_encode_options = { invalid: :replace, undef: :replace }
      c.source_encoding_fallback = Encoding::UTF_8

      yield
    end
  end

  FormatParser.register_parser new, natures: :audio, formats: :mp3, priority: 99
end
