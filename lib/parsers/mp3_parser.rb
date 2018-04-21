require 'ks'

class FormatParser::MP3Parser
  require_relative 'mp3_parser/id3_v1'
  require_relative 'mp3_parser/id3_v2'

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
  MAX_FRAMES_TO_SCAN = 128

  # Default frame size for mp3
  SAMPLES_PER_FRAME = 1152

  # For some edge cases
  ZIP_LOCAL_ENTRY_SIGNATURE = "PK\x03\x04\x14\x00".b

  def call(io)
    # Special case: some ZIPs (Office documents) did detect as MP3s.
    # To avoid having that happen, we check for the PKZIP signature -
    # local entry header signature - at the very start of the file
    return if io.read(6) == ZIP_LOCAL_ENTRY_SIGNATURE
    io.seek(0)

    # Read the last 128 bytes which might contain ID3v1
    id3_v1 = ID3V1.attempt_id3_v1_extraction(io)
    # Read the header bytes that might contain ID3v1
    id3_v2 = ID3V2.attempt_id3_v2_extraction(io)

    # Compute how many bytes are occupied by the actual MPEG frames
    ignore_bytes_at_tail = id3_v1 ? 128 : 0
    ignore_bytes_at_head = id3_v2 ? io.pos : 0
    bytes_used_by_frames = io.size - ignore_bytes_at_tail - ignore_bytes_at_tail

    io.seek(ignore_bytes_at_head)

    maybe_xing_header, initial_frames = parse_mpeg_frames(io)

    return if initial_frames.empty?

    first_frame = initial_frames.first

    file_info = FormatParser::Audio.new(
      format: :mp3,
      num_audio_channels: first_frame.channels,
      audio_sample_rate_hz: first_frame.sample_rate,
      # media_duration_frames is omitted because the frames
      # in MPEG are not the same thing as in a movie file - they
      # do not tell anything of substance
      intrinsics: {
        id3_v1: id3_v1 ? id3_v1.to_h : nil,
        id3_v2: id3_v2 ? id3_v2.map(&:to_h) : nil,
        xing_header: maybe_xing_header.to_h,
        initial_frames: initial_frames.map(&:to_h)
      }
    )

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

    MAX_FRAMES_TO_SCAN.times do |frame_i|
      # Read through until we can latch onto the 11 sync bits. Read in 4-byte
      # increments to save on read() calls
      data = io.read(4)

      # If we are at EOF - stop iterating
      break unless data && data.bytesize == 4

      # Look for the sync pattern. It can be either the last byte being 0xFF,
      # or any of the 2 bytes in sequence being 0xFF and > 0xF0.
      four_bytes = data.unpack('C4')
      seek_jmp = sync_bytes_offset_in_4_byte_seq(four_bytes)
      if seek_jmp > 0
        io.seek(io.pos + seek_jmp)
        next
      end

      # Once we are past that stage we have latched onto a sync frame header
      sync, conf, bitrate_freq, rest = four_bytes
      frame_detail = parse_mpeg_frame_header(io.pos - 4, sync, conf, bitrate_freq, rest)
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
        io.seek(io.pos + frame_detail.frame_length - 4)
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
    header_flags, _ = io.read(4).unpack('s>s>')
    frames = byte_count = toc = vbr_scale = nil

    frames = io.read(4).unpack('N1').first if header_flags & 1 # FRAMES FLAG

    byte_count = io.read(4).unpack('N1').first if header_flags & 2 # BYTES FLAG

    toc = io.read(100).unpack('C100') if header_flags & 4 # TOC FLAG

    vbr_scale = io.read(4).unpack('N1').first if header_flags & 8 # VBR SCALE FLAG

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

  FormatParser.register_parser self, natures: :audio, formats: :mp3
end
