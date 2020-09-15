radar_original_require 'benchmark/ips'

module Benchmark
  class << self
    alias_method :radar_original_ips, :ips
  end

  class RadarContext
    def report(name, &block)
      Radar.benchmark name, &block
    end
  end

  def self.ips(&block)
    RadarContext.new.instance_eval &block
  end
end
