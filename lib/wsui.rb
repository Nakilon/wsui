module WSUI
  require "set"
  require "async/websocket/adapters/rack"
  require "async/http/endpoint"
  require "falcon"
  def self.start html
    app = Module.new do
      @connections = Set.new
      def self.call env
        Async::WebSocket::Adapters::Rack.open env, protocols: %w{ ws } do |connection|
          @connections << connection
          while message = connection.read
            @connections.each do |connection|
              connection.write(message)
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
                let myColor = [100, 100, 100];
                function setup() {
                  createCanvas(200, 200);
                  noStroke();
                  connectWebsocket("ws://localhost:7001");
                }
                function draw() {
                  background(255);
                  fill(myColor);
                  ellipse(width / 2, height / 2, width);
                }
                function mousePressed() {
                  sendMessage({ color: [random(255), random(255), random(255)] });
                }
                function messageReceived(data) {
                  myColor = data.color;
                }
              </script>
            </head>
            <body style="margin:0"><main></main></body>
          </html>
        HEREDOC
      end
    end
    Async do
      websocket_endpoint = Async::HTTP::Endpoint.parse "http://0.0.0.0:7001"
      app_ = Falcon::Server.middleware app
      server = Falcon::Server.new app_, websocket_endpoint
      server.run.each &:wait
    end
  end
end
