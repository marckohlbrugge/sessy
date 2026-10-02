import { Controller } from "@hotwired/stimulus"

// Reloads the Turbo Frame it is attached to on an interval while the tab is
// visible. Stops for good when the frame's content declares a `done` target,
// and pauses after a budget so an abandoned tab does not poll forever; coming
// back to the tab restarts polling with a fresh budget.
export default class extends Controller {
  static targets = [ "done", "paused" ]
  static values = {
    url: String,
    interval: { type: Number, default: 5000 },
    budget: { type: Number, default: 30 * 60 * 1000 }
  }

  connect() {
    this.onVisibilityChange = () => this.visibilityChanged()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    this.start()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    this.stop()
  }

  // Fires on every reload that renders the done state, including the one that
  // transitions a live frame; the frame element itself is never replaced.
  doneTargetConnected() {
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
    if (this.hasDoneTarget || document.visibilityState !== "visible") return

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
