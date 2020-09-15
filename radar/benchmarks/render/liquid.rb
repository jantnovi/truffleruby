require 'liquid'

require 'radar-run'

# Template from Liquid documentation

code = """
<ul id=\"products\">
  {\% for product in products %}
    <li>
      <h2>{{ product.name }}</h2>
      Only {{ product.price | price }}

      {{ product.description | prettyprint | paragraph }}
    </li>
  {\% endfor %}
</ul>
"""

template = Liquid::Template.parse(code)

source = Radar.source
sink = Radar.sink

Radar.benchmark 'liquid-parse' do
  template = Liquid::Template.parse(code)
end

Radar.benchmark 'liquid-render' do
  products = {'products' => [
    {'name' => 'a', 'price' => source.readbyte, 'description' => 'a'},
    {'name' => 'b', 'price' => source.readbyte, 'description' => 'b'},
    {'name' => 'c', 'price' => source.readbyte, 'description' => 'c'}
  ]}
  sink.write template.render!(products)
end

Radar.benchmark 'liquid-parse-render' do
  template = Liquid::Template.parse(code)
  products = {'products' => [
    {'name' => 'a', 'price' => source.readbyte, 'description' => 'a'},
    {'name' => 'b', 'price' => source.readbyte, 'description' => 'b'},
    {'name' => 'c', 'price' => source.readbyte, 'description' => 'c'}
  ]}
  sink.write template.render!(products)
end
