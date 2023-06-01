module WSUI
  require "set"
  require "async/websocket/adapters/rack"
  require "async/http/endpoint"
  require "falcon"
  S = Struct.new :value, :f do
    def click
      f.call self
    end
  end
  def self.start port, html = "", &b
    app = Module.new do
      @connections = Set.new
      @port = port
      @b = b
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
            ObjectSpace._id2ref(message[:id]).click if message.key? :id
            t = f.call(@b.call(message)).to_json
            @connections.each do |connection|
              connection.write t
              connection.flush
            end
          end
        ensure
          @connections.delete(connection)
        end or [200, [], [<<~HEREDOC]]
          <html>
            <head>
              <meta charset="UTF-8">
              <script src="https://github.com/processing/p5.js/releases/download/v1.4.2/p5.min.js"></script>
              <script src="https://cdn.jsdelivr.net/gh/abachman/p5.websocket/dist/p5.websocket.min.js"></script>
              <script>
                var all = null;
                var regions = [];
                function setup() {
                  frameRate(2);
                  createCanvas(windowWidth, windowHeight);
                  textAlign(CENTER, CENTER);
                  connectWebsocket("ws://localhost:#{@port}");
                };
                function messageReceived(data) {
                  all = JSON.parse(data);
                };
                function draw() {
                  console.log(all);
                  clear();
                  regions = [];
                  let fv = function(o, left, top, width, height) {
                    if (o === null) return;
                    if (o.wsui_id) {
                      regions.push({id: o.wsui_id, left: left, top: top, width: width, height: height});
                      o = o.value;
                    };
                    if (Number.isFinite(o) || typeof o === "string" || o instanceof String) {
                      textSize(min(100, textSize() * width / textWidth(o)));
                      text(o, left + width / 2, top + height / 2)
                    } else o.forEach( function(e, i) {
                      fh(e, left, top + height / o.length * i, width, height / o.length);
                    } );
                  };
                  let fh = function(o, left, top, width, height) {
                    if (o === null) return;
                    if (o.wsui_id) {
                      regions.push({id: o.wsui_id, left: left, top: top, width: width, height: height});
                      o = o.value;
                    };
                    if (Number.isFinite(o) || typeof o === "string" || o instanceof String) {
                      textSize(min(100, textSize() * width / textWidth(o)));
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
    Async do
      Falcon::Server.new(
        Falcon::Server.middleware(app),
        Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}")
      ).run.each &:wait
    end
  end
end
