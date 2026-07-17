import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

  // Permanent inputs survive Turbo renders, so sync them with the URL unless the user is typing
  inputTargetConnected(input) {
    if (document.activeElement !== input) {
      input.value = new URLSearchParams(location.search).get(input.name) || ""
    }
  }

  submit() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 300)
  }
}
