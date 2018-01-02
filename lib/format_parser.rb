require 'thread'

Dir.glob(__dir__ + '/**/*.rb').sort.each { |f| require f }

module FormatParser
  PARSERS = [
    FormatParser::Parsers::AudioParser,
    FormatParser::Parsers::DocumentParser,
    FormatParser::Parsers::ImageParser,
    FormatParser::Parsers::VideoParser
  ].freeze

  def self.parse_http(url)
    parse(RemoteIO.new(url))
  end

  def self.parse(io)
    io = Care::IOWrapper.new(io) unless io.is_a?(Care::IOWrapper)
    limited_io = ReadLimiter.new(io, max_bytes: 512 * 1024, max_reads: 64 * 1024, max_seeks: 64 * 1024)

    # Always instantiate parsers fresh for each input, since they might
    # contain instance variables which otherwise would have to be reset
    # between invocations, and would complicate threading situations
    results = PARSERS.inject({}) do |memo, parser|
      begin
        key = parser.name.split('::').last.downcase.gsub('parser', '').to_sym
        io.seek(0)
        memo[key] = parser.new.call(limited_io)
        memo
      rescue IOUtils::InvalidRead
        # There was not enough data for this parser to work on,
        # and it triggered an error
        memo[key] = nil
        memo
      rescue ReadLimiter::BudgetExceeded
        # The parser tried to read too much - most likely the file structure
        # caused the parser to go off-track. Strictly speaking we should log this
        # and examine the file more closely.
        memo[key] = nil
        memo
      end
    end
    return nil if results.values.all?(&:nil?) # Nothing matched
    FormatParser::Result.new(results)
  end
end
