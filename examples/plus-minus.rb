require "../lib/wsui"

x = 0
WSUI.start 7001, "" do
  x = rand
  x
end
