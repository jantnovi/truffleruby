require 'erb'

require 'radar-run'

# Template from ERB documentation

code = "<%= product[:name] %> -- <%= product[:cost] %> <%= product[:desc] %>"

template = ERB.new(code)

source = Radar.source
sink = Radar.sink

product = {
  name: "Chicken Fried Steak",
  desc: "A well messages pattie, breaded and fried.",
  cost: source.readbyte
}

Radar.benchmark 'erb-parse' do
  template = ERB.new(code)
end

Radar.benchmark 'erb-render' do
  product = {
    name: "Chicken Fried Steak",
    desc: "A well messages pattie, breaded and fried.",
    cost: source.readbyte
  }
  sink.write template.result(binding)
end

Radar.benchmark 'erb-parse-render' do
  template = ERB.new(code)
  product = {
    name: "Chicken Fried Steak",
    desc: "A well messages pattie, breaded and fried.",
    cost: source.readbyte
  }
  sink.write template.result(binding)
end
