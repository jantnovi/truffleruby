radar_original_require 'benchmark'

module Benchmark
  class RadarContext
    def report(name=nil, &block)
      name ||= File.basename(caller_locations[3].path, '.*')
      Radar.benchmark name, &block
    end
  end

  def realtime(&block)
    name = File.basename(caller_locations[0].path, '.*')
    Radar.benchmark name, &block
    nil # because people puts the result of calling realtime and this way it won't show up
  end

  def self.realtime(&block)
    name = File.basename(caller_locations[0].path, '.*')
    Radar.benchmark name, &block
    nil # because people puts the result of calling realtime and this way it won't show up
  end

  def self.measure(&block)
    name = File.basename(caller_locations[0].path, '.*')
    Radar.benchmark name, &block
    nil # because people puts the result of calling measure and this way it won't show up
  end

  def self.bm(label_width=0, *labels, &block)
    RadarContext.new.instance_eval &block
  end

  def self.bmbm(label_width=0, *labels, &block)
    RadarContext.new.instance_eval &block
  end

  def self.benchmark(caption='', label_width=nil, format=nil, *labels, &block)
    RadarContext.new.instance_eval &block
  end
end
