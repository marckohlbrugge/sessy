// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import LocalTime from "local-time"

// Follow the browser locale's clock: h23/h24 locales (most of Europe) get
// 24-hour times via the *_24h format variants; h11/h12 keep AM/PM.
const { hourCycle, hour12 } = new Intl.DateTimeFormat(undefined, { hour: "numeric" }).resolvedOptions()
LocalTime.config.useFormat24 = hourCycle ? hourCycle.startsWith("h2") : hour12 === false
LocalTime.start()
