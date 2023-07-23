require "set"
past = Set.new

array = []
require "../lib/wsui"

app = WSUI.start animate: false

def prepare_message(array, past)
  t = array.drop(1).map.with_index(1).to_a
  i = t.index{ |_,i| !_ || !past.include?(i) }
  [[nil, "N", "depth", nil]] + t.drop([i.to_i-2,0].max).chunk{|_,|!_}.flat_map do |flag, chunk|
    flag ? [[nil, "...", nil, nil]] : chunk.map{ |(d, from), i| ["#{from} →", i, d, ("Q" unless past.include? i)] }
  end
end

require "pairing_heap"
heap = PairingHeap::SimplePairingHeap.new
push = lambda do |d, n, from = nil|
  heap.push d, n
  array[n] = [d, from]
end
push.call 0, 1

loop do
  d, n = heap.pop_with_priority
  sleep 2
  push.call d+1, n*2, n unless past.include? n*2
  if n > 1
    a, b = (n-1).divmod(3)
    push.call d+1, a, n unless past.include? a if b.zero?
  end
  past.add n
  app.publish prepare_message(array, past) 
end
