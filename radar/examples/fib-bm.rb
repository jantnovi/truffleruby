require 'benchmark'

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

Benchmark.bm(4) do |x|
  x.report('fib-bm-x') { fib(14) }
  x.report { fib(14) }
end
