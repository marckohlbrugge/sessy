source "https://rubygems.org"

gem "rails", "~> 8.1.1"

# Assets and frontend
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"

# Deployment and drivers
gem "bootsnap", require: false
gem "kamal", require: false
gem "pg", "~> 1.1"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Features
gem "aws-sdk-rails"
gem "aws-sdk-sns"
gem "pagy"

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "minitest", "~> 5.0"
  gem "selenium-webdriver"
end
