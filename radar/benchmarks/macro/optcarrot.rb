require_relative 'optcarrot/lib/optcarrot'

require 'radar-run'

rom = File.expand_path('optcarrot/examples/Lan_Master.nes', __dir__)
nes = Optcarrot::NES.new ['--headless', rom]
nes.reset

Radar.benchmark do
  nes.step
end
