module Kernel
  alias_method :radar_original_require, :require

  def require(feature)
    case feature
    when 'benchmark'
      radar_original_require('radar-run/benchmark')
    when 'benchmark/ips'
      radar_original_require('radar-run/bips')
    else
      radar_original_require(feature)
    end
  end
end

module Radar
  def self.source
    File.open('/dev/urandom', 'r')
  end

  def self.sink
    sink = File.open('/dev/null', 'w')
    sink.sync = true
    sink
  end
end

if $stdout.tty?

  module Radar
    BENCHMARKS = []

    def self.benchmark(name=nil, &block)
      name ||= File.basename(caller_locations[0].path, '.*')
      BENCHMARKS.push [name, block]
    end
  end

  at_exit do
    require 'radar-run/bips'

    Benchmark.radar_original_ips do |x|
      x.warmup = 1
      x.time = 1
      Radar::BENCHMARKS.each do |name, block|
        x.report name, &block
      end
      x.compare! if Radar::BENCHMARKS.size > 1
    end
  end

else

  module Radar
    def self.benchmark(name=nil, &block)
      filter = ENV['RADAR_FILTER']
      return if filter && name && name != filter
      $stdout.sync = true
      benchmark_class = Class.new
      benchmark_class.define_method :run, &block
      benchmark_instance = benchmark_class.new
      begin
        iterations = 1
        loop do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          iterations.times do
            benchmark_instance.run
          end
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
          ips = iterations / elapsed
          iterations = [1, ips.round].max
          puts ips
        end
      rescue Interrupt
        return
      end
    end
  end

end
