# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Sub-path deploys (e.g. reverse proxy at /sessy): Rack::URLMap strips the prefix
# from PATH_INFO for routing and sets SCRIPT_NAME so URL helpers include the mount.
relative_root = ENV["RAILS_RELATIVE_URL_ROOT"].to_s
if !relative_root.empty? && relative_root != "/"
  map(relative_root) { run Rails.application }
else
  run Rails.application
end

Rails.application.load_server
