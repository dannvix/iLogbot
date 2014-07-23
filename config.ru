# Process.setrlimit(Process::RLIMIT_NOFILE, 4096, 65536)
require File.join(File.dirname(__FILE__), "app")

# HTTP basic authentication
# use Rack::Auth::Basic, "iLogbot" do |username, password|
#   password == "secret"
# end

run Rack::URLMap.new \
  "/" => Logbot::App.new,
  "/comet" => Comet::App.new,
  "/assets" => Rack::Directory.new("public")
