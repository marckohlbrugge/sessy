# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "local-time" # @3.0.3
pin "highlight.js/lib/core", to: "https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/es/core.min.js"
pin "highlight.js/lib/languages/ruby", to: "https://cdn.jsdelivr.net/npm/highlight.js@11.11.1/es/languages/ruby.min.js"
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
