module WSUI
  require "set"
  require "async/websocket/adapters/rack"
  require "async/http/endpoint"
  require "falcon"
  S = Struct.new :value, :click
  def self.start port = 7001, html = "", fps: 5, animate: true, &block
    app = Module.new do
      @animate = animate
      @connections = Set.new
      @port = port
      @fps = fps
      @block = block

      def self.f(o)
        if o.is_a? S
          {wsui_id: o.__id__, value: o.value}
        elsif o.respond_to? :each
          o.map &method(:f)
        else
          o
        end
      end

      def self.publish(message)
        @connections.each do |connection|
          puts "write to connection #{connection}"
          connection.write f(message).to_json
          connection.flush
        end
      end

      def self.call env
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

            publish(@block&.call(message) || message) 
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
                  // console.log(all);
                  fv(all, 0, 0, windowWidth, windowHeight);
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

                #{@animate ? 'setInterval(' : 'setTimeout('} function () {
                  sendMessage({});
                }, 300);
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
    return app
  end
end
