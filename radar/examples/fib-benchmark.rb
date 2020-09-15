require 'benchmark'

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

Benchmark.benchmark(Benchmark::CAPTION, 4, Benchmark::FORMAT) do |x|
  x.report('fib-benchmark-x') { fib(14) }
  x.report { fib(14) }
end
