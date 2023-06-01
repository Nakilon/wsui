require "../lib/wsui"

x = 0
WSUI.start 7001, "" do |m|
  [[nil, [
    WSUI::S.new("^", ->_{ x += 1 }),
    x,
    WSUI::S.new("v", ->_{ x -= 1 }),
  ], nil]]
end
