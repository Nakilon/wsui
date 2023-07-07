module WSUI
  require "set"
  require "async/websocket/adapters/rack"
  require "async/http/endpoint"
  require "falcon"
  S = Struct.new :value, :click
  def self.start port = 7001, html = "", fps: 5, &block
    app = Module.new do
      @connections = Set.new
      @port = port
      @fps = fps
      @block = block
      def self.call env
        f = lambda do |o|
          if o.is_a? S
            {wsui_id: o.__id__, value: o.value}
          elsif o.respond_to? :each
            o.map &f
          else
            o
          end
        end
        Async::WebSocket::Adapters::Rack.open env, protocols: %w{ ws } do |connection|
          @connections << connection
          while message = connection.read
            if message.key? :id
              t = begin
                ObjectSpace._id2ref message[:id]
              rescue RangeError
                # maybe when we click too fast and the page has 'old' refs
              end
              p t
              t.click&.call t if t.respond_to? :click
            end
            t = f.call(@block.call(message)).to_json
            @connections.each do |connection|
              connection.write t
              connection.flush
            end
          end
        rescue Protocol::WebSocket::ClosedError
          p :closed
        ensure
          @connections.delete connection
        end or [200, [], [<<~HEREDOC]]
          <html>
            <head>
              <meta charset="UTF-8">
              <script src="https://github.com/processing/p5.js/releases/download/v1.4.2/p5.min.js"></script>
              <script src="https://cdn.jsdelivr.net/gh/abachman/p5.websocket/dist/p5.websocket.min.js"></script>
              <script>
                var all = null;
                var regions = [];
                var need = false;   // force draw() on click
                function setup() {
                  frameRate(#{@fps});
                  createCanvas(windowWidth, windowHeight);
                  textAlign(CENTER, CENTER);
                  connectWebsocket("ws://" + window.location.host);
                };
                function messageReceived(data) {
                  // console.log(data);
                  all = JSON.parse(data);
                  if (need) {
                    need = false;
                    draw();
                  }
                };
                function draw() {
                  // console.log(all);
                  clear();
                  regions = [];
                  let fv = function(o, left, top, width, height) {
                    if (o && o.wsui_id) {
                      regions.push({id: o.wsui_id, left: left, top: top, width: width, height: height});
                      o = o.value;
                    };
                    if (o === null) return;
                    if (Number.isFinite(o) || typeof o === "string" || o instanceof String) {
                      textSize(min(100, textSize() * min(height / textWidth("W"), width / textWidth(o))));
                      text(o, left + width / 2, top + height / 2)
                    } else o.forEach( function(e, i) {
                      fh(e, left, top + height / o.length * i, width, height / o.length);
                    } );
                  };
                  let fh = function(o, left, top, width, height) {
                    if (o && o.wsui_id) {
                      regions.push({id: o.wsui_id, left: left, top: top, width: width, height: height});
                      o = o.value;
                    };
                    if (o === null) return;
                    if (Number.isFinite(o) || typeof o === "string" || o instanceof String) {
                      textSize(min(100, textSize() * min(height / textWidth("W"), width / textWidth(o))));
                      text(o, left + width / 2, top + height / 2)
                    } else o.forEach( function(e, i) {
                      fv(e, left + width / o.length * i, top, width / o.length, height);
                    } );
                  };
                  fv(all, 0, 0, windowWidth, windowHeight);
                  sendMessage({});
                };
                function mouseClicked() {
                  regions.some( function(e) {
                    if (mouseX >= e.left && mouseX <= e.left + e.width && mouseY >= e.top && mouseY <= e.top + e.height) {
                      sendMessage({id: e.id});
                      need = true;
                      return true;
                    };
                  } );
                };
              </script>
            </head>
            <body style="margin:0"><main></main></body>
          </html>
        HEREDOC
      end
    end
    Thread.new do
      Async do
        Falcon::Server.new(
          Falcon::Server.middleware(app),
          Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
        ).run
      end
    end
  end
end
