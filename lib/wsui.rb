module WSUI
  require "set"
  require "async/websocket/adapters/rack"
  require "async/http/endpoint"
  require "falcon"
  def self.start port, html, &b
    app = Module.new do
      @connections = Set.new
      @port = port
      @b = b
      def self.call env
        Async::WebSocket::Adapters::Rack.open env, protocols: %w{ ws } do |connection|
          @connections << connection
          while message = connection.read
            t = @b.call(message).to_json
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
                var data;
                function setup() {
                  frameRate(10);
                  createCanvas(windowWidth, windowHeight);
                  connectWebsocket("ws://localhost:#{@port}");
                }
                function messageReceived(input) {
                  data = input;
                }
                function draw() {
                  console.log(data);
                  sendMessage({});
                }
                function mousePressed() {
                }
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
