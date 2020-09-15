require 'rack'

require 'radar-run'

SOURCE = Radar.source

module Rack
  class RackApp
    def call(env)
      res = Response.new
      res.write "Hello, #{SOURCE.readbyte} World!"
      res.finish
    end
  end
end

env = Rack::MockRequest.env_for("tcp://0.0.0.0:9292")

rack_app = Rack::RackApp.new

sink = Radar.sink

Radar.benchmark do
  response = rack_app.call(env)
  response_code = response[0]
  if response_code != 200
    raise "bad response #{response}"
  end
  sink.write response
end
