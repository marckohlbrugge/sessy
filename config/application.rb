require_relative "boot"

# Loaded explicitly (and ignored by the autoloader below): the Sessy constant
# is already defined as the app namespace, so a bare Sessy.saas? call would
# never trigger an autoload of lib/sessy.rb in a lazy (non-eager) boot.
require_relative "../lib/sessy"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sessy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks sessy.rb])

    # Display-only host for the MCP endpoint URL shown in docs and connect
    # snippets. Hosted sets it to the api subdomain; self-hosted leaves it
    # unset and the docs fall back to the request host.
    config.x.api_host = ENV["API_HOST"]

    config.active_storage.variant_processor = :disabled

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
