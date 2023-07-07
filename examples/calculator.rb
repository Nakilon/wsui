module Calculator
  @shown = @left = @right = 0
  Operation = Struct.new :callback, :name
  private_constant :Operation
  @appending = false
  @operation = Operation.new ->{ @left = @right; @appending = false }
  class << self
    attr_reader :shown, :operation

    def digit n
      if @appending
        @right = @right * 10 + n
      else
        @right = n
        @appending = true
      end
      @shown = @right
    end
    def equal
      @operation.callback.call
    end
    def +
      equal if @appending; @right = 0; @appending = false
      @operation = Module.nesting[1].const_get(:Operation).new ->{ @shown = @left = @left + @right; @appending = false }, "oper: +"
    end
    def -
      equal if @appending; @right = 0; @appending = false
      @operation = Module.nesting[1].const_get(:Operation).new ->{ @shown = @left = @left - @right; @appending = false }, "oper: -"
    end
    def ×
      equal if @appending; @right = 0; @appending = false
      @operation = Module.nesting[1].const_get(:Operation).new ->{ @shown = @left = @left * @right; @appending = false }, "oper: ×"
    end
    def ÷
      equal if @appending; @right = 0; @appending = false
      @operation = Module.nesting[1].const_get(:Operation).new ->{ @shown = @left = @left.fdiv @right; @appending = false }, "oper: ÷"
    end

  end
end
c = Calculator

require "../lib/wsui"
WSUI.start fps: 5 do |*|
  [
    [c.shown, c.operation.name],
    [WSUI::S.new(7, ->*{ c.digit 7 }), WSUI::S.new(8, ->*{ c.digit 8 }), WSUI::S.new(9, ->*{ c.digit 9 }), WSUI::S.new(?÷, ->*{ c.÷ })],
    [WSUI::S.new(4, ->*{ c.digit 4 }), WSUI::S.new(5, ->*{ c.digit 5 }), WSUI::S.new(6, ->*{ c.digit 6 }), WSUI::S.new(?×, ->*{ c.× })],
    [WSUI::S.new(1, ->*{ c.digit 1 }), WSUI::S.new(2, ->*{ c.digit 2 }), WSUI::S.new(3, ->*{ c.digit 3 }), WSUI::S.new(?-, ->*{ c.- })],
    [WSUI::S.new(0, ->*{ c.digit 0 }), WSUI::S.new(?=, ->*{ c.equal  }),                                   WSUI::S.new(?+, ->*{ c.+ })],
  ]
end
gets
