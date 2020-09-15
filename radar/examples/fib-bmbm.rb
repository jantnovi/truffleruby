require 'benchmark'

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

Benchmark.bmbm(4) do |x|
  x.report('fib-bmbm-x') { fib(14) }
  x.report { fib(14) }
end
