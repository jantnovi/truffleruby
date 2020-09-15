# Survey

## Clocks

The clock that most benchmark use `Process.clock_gettime(Process::CLOCK_MONOTONIC)`, which returns seconds from an arbitrary origin as a `Float`. As the name describes, it's monotonic.

The resolution is obtainable from `Process.clock_getres(Process::CLOCK_MONOTONIC)`, and is usually microseconds. You may want to confirm this in a benchmarking harness.

```ruby
raise 'CLOCK_MONOTONIC seems low resolution' unless Process.clock_getres(Process::CLOCK_MONOTONIC) <= 1e-6
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
sleep 3
puts Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
```

## Benchmarking harnesses

### Standard library

#### `Benchmark.realtime`

```ruby
require 'benchmark'
puts Benchmark.realtime { 'foo' + 'bar' }
```

This prints elapsed wall-clock time in seconds.

```
2.9999937396496534e-06
```

#### `Benchmark.measure`

```ruby
require 'benchmark'
puts Benchmark.measure { 'foo' + 'bar' }
```

This prints in seconds:

* user CPU time
* system CPU time
* total CPU time
* wall-clock time

```
  0.000007   0.000007   0.000014 (  0.000005)
```

#### `Benchmark.bm`

The helper method `Benchmark.bm` lets you write a table of results from several benchmarks, but each is run in the same way as in `Benchmark.measure`.

```ruby
require 'benchmark'
Benchmark.bm do |bm|
  bm.report { 'foo' + 'bar' }
  bm.report { ['foo', 'bar'].join('') }
end
```

```
       user     system      total        real
   0.000005   0.000003   0.000008 (  0.000004)
   0.000002   0.000000   0.000002 (  0.000002)
```

It's additionally possible to add labels to each benchmark.

#### `Benchmark.bmbm`

```ruby
require 'benchmark'
Benchmark.bmbm do |bm|
  bm.report { 'foo' + 'bar' }
  bm.report { ['foo', 'bar'].join('') }
end
```

This runs each benchmark twice, once as a rehearsal and once for timing.

```
Rehearsal ------------------------------------
   0.000004   0.000002   0.000006 (  0.000004)
   0.000002   0.000001   0.000003 (  0.000002)
--------------------------- total: 0.000009sec

       user     system      total        real
   0.000002   0.000000   0.000002 (  0.000002)
   0.000002   0.000001   0.000003 (  0.000002)
```

#### `Benchmark.benchmark`

`Benchmark.benchmark` is a version of `Benchmark.bm` with more control over formatting, but it benchmarks in the same way.

```ruby
require 'benchmark'
Benchmark.benchmark(Benchmark::CAPTION, 7, Benchmark::FORMAT, 'total', 'mean') do |x|
  concat = x.report('concat') { 'foo' + 'bar' }
  join = x.report('join') { ['foo', 'bar'].join }
  [concat + join, (concat + join) / 2]
end
```

```
              user     system      total        real
concat    0.000005   0.000002   0.000007 (  0.000003)
join      0.000002   0.000000   0.000002 (  0.000002)
total     0.000007   0.000002   0.000009 (  0.000005)
mean      0.000004   0.000001   0.000005 (  0.000003)
```

### Third-party gems

#### `benchmark-ips`

https://github.com/evanphx/benchmark-ips

`benchmark-ips` is the benchmarking harness that most people would recommend to use in Ruby if they have at least some experience in benchmarking. It was created by Evan Phoenix as part of his work on Rubinius, which was one of the first optimizing implementations of Ruby.

```ruby
require 'benchmark/ips'
Benchmark.ips do |x|
  x.report('concat') { 'foo' + 'bar' }
  x.report('join') { ['foo', 'bar'].join('') }
  x.compare!
end
```

`Benchmark.ips` reports iterations-per-second, and it has a warm-up phase. It can run multiple benchmarks, like `Benchmark.bm`, and it can compare results. It reports one standard-deviation as the error.

```
Warming up --------------------------------------
              concat   705.966k i/100ms
                join   294.140k i/100ms
Calculating -------------------------------------
              concat      6.979M (± 1.7%) i/s -     35.298M in   5.059249s
                join      3.077M (± 2.5%) i/s -     15.589M in   5.070151s

Comparison:
              concat:  6979010.6 i/s
                join:  3076562.1 i/s - 2.27x  (± 0.00) slower
```

The warmup feature in `Benchmark.ips` runs by default for two seconds. For the first half of the warmup time it keeps doubling the number of iterations it runs in each timing run to find a number of iterations that takes around 100ms. Then it runs the measurement run, running as many times this number of iterations as to run for the full timing duration, which is five seconds by default.

A useful feature is that `benchmark-ips` will warn the user if it appears that the difference is not significant.

```ruby
require 'benchmark/ips'
Benchmark.ips do |x|
  x.report('foobar') { 'foo' + 'bar' }
  x.report('barfoo') { 'bar' + 'foo' }
  x.compare!
end
```

```
Comparison:
              barfoo:  6995890.1 i/s
              foobar:  6965480.1 i/s - same-ish: difference falls within error
```

#### `benchmark-memory`

https://github.com/michaelherold/benchmark-memory

`benchmark-memory` is like `benchmark-ips` but reports object allocations rather than time. There's no warmup phase though.

```ruby
require 'benchmark/memory'
Benchmark.memory do |x|
  x.report('concat') { 'foo' + 'bar' }
  x.report('join') { ['foo', 'bar'].join('') }
  x.compare!
end
```

```
Calculating -------------------------------------
              concat   120.000  memsize (     0.000  retained)
                         3.000  objects (     0.000  retained)
                         3.000  strings (     0.000  retained)
                join   200.000  memsize (     0.000  retained)
                         5.000  objects (     0.000  retained)
                         4.000  strings (     0.000  retained)

Comparison:
              concat:        120 allocated
                join:        200 allocated - 1.67x more
```

`benchmark-memory` measures memory using another gem, `memory_profiler` https://github.com/SamSaffron/memory_profiler, which in turn uses the built-in API `ObjectSpace.trace_object_allocations_start`.

#### `benchmark-driver`

https://github.com/benchmark-driver/benchmark-driver

`benchmark-driver` was created by Takashi Kokubun, who is working on Ruby 3x3 and the MJIT optimizer. It's designed to allow comparing different Ruby implementations, as well as comparing different snippets of Ruby. You can use it mostly like `benchmark-ips`.

```ruby
require 'benchmark_driver'
Benchmark.driver do |x|
  x.report 'concat', %{ 'foo' + 'bar' }
  x.report 'join', %{ ['foo', 'bar'].join('') }
end
```

```
Warming up --------------------------------------
              concat     8.807M i/s -      8.993M times in 1.021119s (113.55ns/i)
                join     3.433M i/s -      3.520M times in 1.025198s (291.25ns/i)
Calculating -------------------------------------
              concat     9.907M i/s -     26.420M times in 2.666782s (100.94ns/i)
                join     3.621M i/s -     10.300M times in 2.844401s (276.14ns/i)

Comparison:
              concat:   9907000.3 i/s 
                join:   3621290.4 i/s - 2.74x  slower
```

You can also write benchmarks in YAML files.

```yaml
benchmark:
  concat: "'foo' + 'bar'"
  join: "['foo', 'bar'].join('')"
```

```
% benchmark-driver bench.yaml 
Warming up --------------------------------------
              concat     8.983M i/s -      9.022M times in 1.004346s (111.32ns/i)
                join     3.402M i/s -      3.484M times in 1.024014s (293.91ns/i)
Calculating -------------------------------------
              concat     9.679M i/s -     26.949M times in 2.784132s (103.31ns/i)
                join     3.574M i/s -     10.207M times in 2.855782s (279.78ns/i)

Comparison:
              concat:   9679482.5 i/s 
                join:   3574270.4 i/s - 2.71x  slower
```

Different Ruby implementations can be compared.

```
$ benchmark-driver example_single.yml --rbenv '2.4.1;2.5.0'
Warming up --------------------------------------
          erb.result    71.683k i/s
Calculating -------------------------------------
                          2.4.1       2.5.0
          erb.result    72.387k     75.046k i/s -    215.049k times in 2.970833s 2.865581s

Comparison:
                       erb.result
               2.5.0:     75045.5 i/s
               2.4.1:     72386.8 i/s - 1.04x  slower
```

There are also tools for storing intermediate results and for rendering results in different formats.

`benchmark-driver` runs a similar two-phase warmup operation to `benchmark-ips` in order to work out how to long for when measuring, but it does so in a separate process, so that this doesn't help for optimization.

## Discussion

### Clock overhead

`Process.clock_gettime(Process::CLOCK_MONOTONIC)` doesn't quite just make the equivalent system call - it accepts different clock names and units.

```ruby
require 'benchmark/ips'
Benchmark.ips do |x|
  x.report('P.clock_gettime') { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
end
```

```
Warming up --------------------------------------
     P.clock_gettime   670.515k i/100ms
Calculating -------------------------------------
     P.clock_gettime      6.535M (± 5.6%) i/s -     32.855M in   5.047219s
```

Therefore we may want to make sure we limit how often we are calling `Process.clock_gettime(Process::CLOCK_MONOTONIC)` in order to amortize the cost.

### How many iterations to run

How many iterations of a benchmark should you run? Some Ruby implementations run micro-benchmarks thousands of times faster than others. The benchmark cannot reasonably hard-code a number of iterations. This also interacts with the overhead of reading the clock - if we want to check the clock perhaps once a second then we need to know how many iterations to run before we next check the clock.

The standard library `Benchmark` module doesn't do anything to help you pick a number of iterations. `benchmark-ips` and `benchmark-driver` uses their warmup phases to find out how many iterations can be run in a set time and then scales the number of iterations for the measurement phase.

### Allowing for optimization

Many people want to measure the peak performance of a benchmark. If you want to do that then you need to let the runtime optimize the program before you start measuring the peak performance. Note that recent research shows us that [benchmarks and runtimes may not warm up as we expect](https://arxiv.org/pdf/1602.00602.pdf), so the problem can be very complex. Also note that there are legitimate reasons why would you want want to measure things other than peak performance, we'll assume for this section that we do want to measure just peak performance on its own.

There are several complex and subtle things to consider here:

* what are the compilation thresholds?
* can loop bodies be compiled independently of the method they're in?
* does a loop body or method reaching a threshold cause methods lower down the stack to be compiled instead?
* can you jump into compiled code or do you need to wait to enter it again?

Most routines in the standard library `Benchmark` module do nothing to allow for optimization. `bmbm` runs a rehearsal, but it only executes the benchmark block once. `benchmark-driver` runs warmup in a separate process so does not help for optimization. `benchmark-ips` runs the benchmark block body many times during warmup. But how many times is enough? In `benchmark-ips` the time can be configured, but this requires human judgement.

This is a tricky problem and you likely carefully need to manually check that your benchmarks are in fact warming up on each implementation you care about. There may not be any great solutions.

Tools including printing when methods are compiled, monitoring how many compilations remain in the compilation queue, and observing what proportion of time is being spent in compiled code.

In TruffleRuby for example we can use `--engine.TraceCompilation` and `--thermometer`.

### Avoiding deoptimisation

When you have got your Ruby implementation to optimize, you need to make sure it stays optimized. Ruby implementations may optimize Ruby by assuming that the program has reached a stable configuration. A potential problem is that the stable configuration is upset when moving from the benchmark's warmup phase to the configuration phase.

We can see this in practice in old version of `benchmark-ips`, such as `2.7.0`. The method `call_times` is compiled assuming it will always be run with a constant number of iterations, as it was during the warmup. When the number of iterations is then set for measurement, the very first thing that happened was the method was invalidated, so the measurement phase starts in the interpreter.

```
Warming up --------------------------------------
...
[engine] opt done         Benchmark::IPS::Job::Entry#call_times ...
Calculating -------------------------------------
[engine] opt invalidated  Benchmark::IPS::Job::Entry#call_times ...
```

Versions of `benchmark-ips` from `2.8.0` vary the number of iterations being run during warmup so that a constant number of iterations is not compiled in, and is only compiled once.

```
Warming up --------------------------------------
...
[engine] opt done         #<Class:#<Benchmark::IPS::Job::Entry:0x228>>#call_times ...
Calculating -------------------------------------
...
```

### Avoiding a benchmark being optimized away

Implementations of Ruby can optimize by not repeating work when the inputs haven't changed, and not doing the work to produce results which aren't used. This can mean that you aren't benchmarking what you think you are.

Like trying to measure peak-performance, this is an extremely subtle and complex problem. Ruby implementation techniques that may cause issues here include:

* constant folding
* profiling dynamic values to determine that they are actually constant
* removing object allocations
* lazy operations, like lazy string concatenation that the benchmark doesn't force

For example, TruffleRuby is able to completely optimize away the string concatenation benchmark we've been using as an example, since the result is never used TruffleRuby does not bother doing it. And even if it was used - it's a constant operation - every iteration of the loop is the same, so it would only do it once.

```ruby
# % ruby --experimental-options --engine.CompileOnly=run --vm.Dgraal.Dump=Truffle:2  test.rb

def run
  1000.times do
    'foo' + 'bar'
  end
end

loop do
  run
end
```

Is a solution to add sources and sinks that are opaque to the optimizer? For example `Benchmark.source(14)` could produce a value and make it appear to be dynamic to the optimizer, and `Benchmark.sink(x)` could make the value appear to be used to the optimizer. Unfortunately even if a value appears to be constant when it's produced, it could be profiled to be constant in later operations.

For example, TruffleRuby realizes that the value of `x` is always zero in this benchmark, even though it comes from an opaque source - a system call, and it compiles `run` to just return a constant value `100` without doing the addition.

```ruby
# % ruby --experimental-options --engine.CompileOnly=run --vm.Dgraal.Dump=Truffle:2  test.rb

def run(x)
  100 + x
end

source = File.open('/dev/zero', 'r')

loop do
  run(source.readbyte)
end
```

The real solution is probably to use system calls as the source and sink, and to make sure values actually vary. For example if we were writing an ERB benchmark we should include input from something like `/dev/random` and actually write the output to `/dev/null`. Unfortunately this does add some overhead so we should try and use the simplest operations we can.

```ruby
require 'benchmark/ips'
require 'erb'
source = File.open('/dev/random', 'r')
sink = File.open('/dev/null', 'w')
template = ERB.new('<%= x %> + <%= y %> = <%= x + y %>')
Benchmark.ips do |x|
  x.report('erb') {
    x = source.readbyte
    y = source.readbyte
    sink.puts template.result(binding)
  }
end
```

### Notes

Demos with TruffleRuby are using `20.1.0`.

## Benchmark suites

Ruby doesn't have an equivalent to for example Octane.

### MRI

https://github.com/ruby/ruby/tree/master/benchmark

The MRI benchmarks are usually micro-benchmarks, are set up to use benchmarking harnesses with issues already described, do not optimize, and if they did they usually do nothing to prevent them from being optimized away.

In the past they used the standard library `Benchmark` module, and some don't use any harness at all.

```ruby
for i in 1..30_000_000
  #
end
```

Most are now set up to use `benchmark-driver`.

```yaml
prelude: |
  small_hash = { a: 1 }
  larger_hash = 20.times.map { |i| [('a'.ord + i).chr.to_sym, i] }.to_h
benchmark:
  dup_small: small_hash.dup
  dup_larger: larger_hash.dup
loop_count: 10000
```

### Optcarrot

https://github.com/mame/optcarrot

Optcarrot is a NES emulator and has been the focus for Ruby 3x3. It's a non-trivial application, and the harness can simply be observing the number of frames-per-second it can render.

### Rails Simpler Bench

https://github.com/noahgibbs/rsb

Rails Simpler Bench uses real Ruby ecosystem frameworks like Rack and Rails to set up routes, but then each route does something pretty simple such as returning static text.

### Rails Ruby Bench

https://github.com/noahgibbs/rails_ruby_bench

Rails Ruby Bench is the full Discourse forum software set up as a benchmark.

### Other benchmarks

* Some gems come with benchmarks
* JRuby has some benchmarks https://github.com/jruby/jruby/tree/master/bench
* TruffleRuby has some benchmarks https://github.com/oracle/truffleruby/tree/master/bench
