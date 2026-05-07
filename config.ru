# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Mount the Rails app under RAILS_RELATIVE_URL_ROOT via Rack::URLMap when
# Sessy is being served from a sub-path (e.g. behind a reverse proxy at
# /sessy or /admin/sessy). URLMap strips the prefix from PATH_INFO so the
# Rails router matches the canonical routes, and sets SCRIPT_NAME on the
# inner request so URL helpers in views, forms, redirects, and the asset
# pipeline emit correctly-prefixed URLs (including the webhook URL shown
# on the source setup page).
#
# Without this, RAILS_RELATIVE_URL_ROOT only affects URL generation
# OUTSIDE a request context (mailers, jobs). In-request URL helpers see
# request.script_name == "" and emit unprefixed paths, breaking every
# link Sessy renders when mounted at a sub-path.
relative_root = ENV["RAILS_RELATIVE_URL_ROOT"].to_s
if !relative_root.empty? && relative_root != "/"
  map(relative_root) { run Rails.application }
else
  run Rails.application
end

Rails.application.load_server
