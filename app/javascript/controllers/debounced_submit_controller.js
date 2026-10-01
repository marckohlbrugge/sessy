import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  // Permanent inputs survive Turbo renders, so sync them with the URL unless the user is typing
  inputTargetConnected(input) {
    if (document.activeElement !== input) {
      input.value = new URLSearchParams(location.search).get(input.name) || ""
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 300)
  }

  // For discrete controls (selects, radios): a debounce window would let a
  // second change land on a form Turbo has already replaced and be dropped.
  submitNow() {
    clearTimeout(this.timer)
    this.element.requestSubmit()
  }
}
