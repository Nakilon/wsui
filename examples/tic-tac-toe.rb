require "../lib/wsui"

state = turn = nil
reset = lambda do
  state = [[nil,nil,nil],[nil,nil,nil],[nil,nil,nil]]
  turn = "X"
end
reset.call
WSUI.start do |*|
  [
    [[0,0],[0,1],[0,2]],
    [[1,0],[1,1],[1,2]],
    [[2,0],[2,1],[2,2]],
    [[0,0],[1,0],[2,0]],
    [[0,1],[1,1],[2,1]],
    [[0,2],[1,2],[2,2]],
    [[0,0],[1,1],[2,2]],
    [[0,2],[1,1],[2,0]],
  ].find do |(i1,j1),(i2,j2),(i3,j3)|
    break WSUI::S.new "'#{state[i1][j1]}' won", ->*{ reset.call } if \
      state[i1][j1] && state[i1][j1] == state[i2][j2] && state[i2][j2] == state[i3][j3]
  end or if state.flatten.all?
    WSUI::S.new "draw", ->*{ reset.call }
  else
    (0..2).map do |i|
      (0..2).map do |j|
        WSUI::S.new state[i][j], ->*{ turn = (%w{ X O } - [state[i][j] = turn])[0] unless state[i][j] }
      end
    end
  end
end
