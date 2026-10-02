import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Reloads the Turbo Frame it is attached to on an interval while the tab is
// visible. When a reload brings back a different setup status than the page
// was rendered with, it re-renders the whole page from the server so the open
// step advances (the server owns which step is open). Pauses after a budget
// so an abandoned tab does not poll forever; coming back to the tab restarts
// polling with a fresh budget.
export default class extends Controller {
  static targets = [ "paused" ]
  static values = {
    url: String,
    status: String,
    interval: { type: Number, default: 5000 },
    budget: { type: Number, default: 30 * 60 * 1000 }
  }

  connect() {
    this.onVisibilityChange = () => this.visibilityChanged()
    this.onFrameLoad = () => this.frameLoaded()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    this.element.addEventListener("turbo:frame-load", this.onFrameLoad)
    this.start()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    this.element.removeEventListener("turbo:frame-load", this.onFrameLoad)
    this.stop()
  }

  // The paused notice's reload link: check again right now, no page load.
  restart(event) {
    event.preventDefault()
    this.start()
    this.load()
  }

  start() {
    this.stop()
    if (document.visibilityState !== "visible") return

    this.deadline = Date.now() + this.budgetValue
    this.timer = setInterval(() => this.tick(), this.intervalValue)
    this.showPaused(false)
  }

  stop() {
    clearInterval(this.timer)
    this.timer = null
  }

  tick() {
    if (Date.now() >= this.deadline) {
      this.stop()
      this.showPaused(true)
    } else {
      this.load()
    }
  }

  // Assigning src makes Turbo load the frame; reload() only re-fetches an
  // existing src. The frame starts without one so the page does not fetch
  // what it has just rendered.
  load() {
    if (this.element.src) {
      this.element.reload()
    } else {
      this.element.src = this.urlValue
    }
  }

  // A replace visit to the current URL is a Turbo page refresh: the server
  // re-renders header, steps and frame from one state, so they always agree.
  frameLoaded() {
    const status = this.element.querySelector("[data-setup-status]")?.dataset.setupStatus
    if (status && status !== this.statusValue) {
      this.stop()
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }

  visibilityChanged() {
    if (document.visibilityState === "visible") {
      this.start()
    } else {
      this.stop()
    }
  }

  showPaused(paused) {
    if (this.hasPausedTarget) this.pausedTarget.hidden = !paused
  }
}
