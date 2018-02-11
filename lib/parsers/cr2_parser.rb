class FormatParser::CR2Parser
  include FormatParser::IOUtils

  def call(io)
    io = FormatParser::IOConstraint.new(io)
    io.seek(8)
    cr2_check_bytes = io.read(2)

    # Check whether it's a CR2 file
    return unless cr2_check_bytes == 'CR'
  end
  def parse_ifd(io, offset)
    io.seek(offset)
    entries_count = safe_read(io, 2).reverse.bytes.collect{ |c| c.to_s(16) }.join.hex
    entries_count.times do |index|
      entry = safe_read(io, 12)
      id = entry[0..1].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      type = entry[2..3].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      count = entry[4..7].bytes.reverse.map { |b| sprintf("%02X",b) }.join.hex
      value = entry[8..11].bytes.reverse.map { |b| sprintf("%02X",b) }.join
    end
  end
end
