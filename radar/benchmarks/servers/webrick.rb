require 'webrick'
require 'net/http'

require 'radar-run'

server = WEBrick::HTTPServer.new(
  :BindAddress => '127.0.0.1',
  :Port => 12345,
  :AccessLog => [],
  :DoNotReverseLookup => true)

source = Radar.source

server.mount_proc '/benchmark' do |req, res|
  res.body = "Hello, #{source.readbyte} world!\n"
end

trap 'INT' do
  server.shutdown
end

Thread.new do
  server.start
end

uri = URI('http://127.0.0.1:12345/benchmark')
request = Net::HTTP::Get.new uri
sink = Radar.sink

Net::HTTP.start(uri.host, uri.port) do |http|
  Radar.benchmark do
    response = http.request request
    if response.code != '200'
      raise "bad response #{response}"
    end
    sink.puts response.body
  end
end
