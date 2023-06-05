require "../lib/wsui"

a = b = 0
WSUI.start do |*|
  [[
    [WSUI::S.new("^", ->*{ a += 1 }), a, WSUI::S.new("v", ->*{ a -= 1 })],
    [WSUI::S.new("^", ->*{ b += 1 }), b, WSUI::S.new("v", ->*{ b -= 1 })],
  ]]
end
