require 'radar-run'

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

Radar.benchmark do
  fib(14)
end
