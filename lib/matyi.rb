require_relative 'format_parser'

# d = '/Users/duplamatyi/work/format_parser/369151__pausenraum__moog-laughing.aiff'

# file_info = FormatParser.parse(File.open(d, "rb"))

# p file_info.file_nature
# p file_info.file_type

# d = '/Users/duplamatyi/work/format_parser/18210__roil-noise__circuitbent-casio-ctk-550-loop1.wav'
# d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAV/c_copy.wav'
# d = '/Users/duplamatyi/work/format_parser/11kulaw.wav'
# d = '/Users/duplamatyi/work/format_parser/output.mp3'
# d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAVE/M1F1-Alaw-AFsp.wav'
# d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAV/c_8kmp316.wav'
d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAV/39064__alienbomb__atmo-truck.wav'
# d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAVE/c_11k8bitpcm.wav'
# d = '/Users/duplamatyi/work/format_parser/spec/fixtures/WAV/6_Channel_ID.wav'

file_info = FormatParser.parse(File.open(d, "rb"))

p file_info.file_nature
p file_info.file_type
p file_info.num_audio_channels
p file_info.audio_sample_rate_hz
p file_info.media_duration_frames
p file_info.media_duration_seconds

# d = '/Users/duplamatyi/work/format_parser/191048__stomachache__96kelectrickalimba-o1harmonic.wav'
# file_info = FormatParser.parse(File.open(d, "rb"))

# p file_info.file_nature
# p file_info.file_type
# p file_info.num_audio_channels
# p file_info.audio_sample_rate_hz
# p file_info.media_duration_frames
# p file_info.media_duration_seconds

# d = '/Users/duplamatyi/work/format_parser/11k16bitpcm.wav'

# file_info = FormatParser.parse(File.open(d, "rb"))

# p file_info.file_nature
# p file_info.file_type
# p file_info.num_audio_channels
# p file_info.audio_sample_rate_hz
# p file_info.media_duration_frames
# p file_info.media_duration_seconds

# d = '/Users/duplamatyi/work/format_parser/8kmp316.wav'

# file_info = FormatParser.parse(File.open(d, "rb"))

# p file_info.file_nature
# p file_info.file_type
# p file_info.num_audio_channels
# p file_info.audio_sample_rate_hz
# p file_info.media_duration_frames
# p file_info.media_duration_seconds
