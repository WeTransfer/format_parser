require 'spec_helper'
require 'webrick'

describe 'Fetching data from HTTP remotes' do
  before(:all) do
    log_file ||= StringIO.new
    log = WEBrick::Log.new(log_file)
    options = {
      :Port => 9399,
      :Logger => log,
      :AccessLog => [
          [ log, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
          [ log, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
       ]
    }
    @server = WEBrick::HTTPServer.new(options)
    @server.mount '/', WEBrick::HTTPServlet::FileHandler, fixtures_dir
    trap("INT") { @server.stop }
    @server_thread = Thread.new { @server.start }
  end

  it 'parses the animated PNG over HTTP' do
    file_information = FormatParser.parse_http('http://localhost:9399/PNG/anim.png')
    expect(file_information).not_to be_nil
    expect(file_information.file_nature).to eq(:image)
  end

  it 'parses the JPEGs exif data' do
    file_information = FormatParser.parse_http('http://localhost:9399/exif-orientation-testimages/jpg/top_left.jpg')
    expect(file_information).not_to be_nil
    expect(file_information.file_nature).to eq(:image)
    expect(file_information.file_type).to eq(:jpg)
    expect(file_information.orientation).to eq(:top_left)
  end

  it 'parses the TIFFs exif data' do
    file_information = FormatParser.parse_http('http://localhost:9399/TIFF/test.tif')
    expect(file_information).not_to be_nil
    expect(file_information.file_nature).to eq(:image)
    expect(file_information.file_type).to eq(:tif)
    expect(file_information.orientation).to eq(:top_left)
  end

  after(:all) do
    @server.stop
    @server_thread.join(0.5)
  end
end
