Gem::Specification.new do |spec|
  spec.name         = "wsui"
  spec.version      = "0.0.0"
  spec.summary      = "websockets-based HTML GUI framework to access runtime objects"
  spec.metadata     = {"source_code_uri" => "https://github.com/nakilon/wsui"}

  spec.author       = "Victor Maslov aka Nakilon"
  spec.email        = "nakilon@gmail.com"
  spec.license      = "MIT"

  spec.required_ruby_version = ">=2.5"    # just for do-ensure-end

  spec.add_dependency "protocol-websocket", "<0.11.0"   # https://github.com/socketry/protocol-websocket/issues/13
  spec.add_dependency "async-websocket"
  spec.add_dependency "falcon", ">0.12.0"   # the "require event/terminal" exception

  spec.files        = %w{ LICENSE wsui.gemspec lib/wsui.rb }
end
