require 'benchmark/ips'

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

Benchmark.ips do |x|
  x.report('fib-bips-1') { fib(14) }
  x.report('fib-bips-2') { fib(14) }
end
