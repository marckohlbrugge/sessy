import { Controller } from "@hotwired/stimulus"

// Copies the source target's text and swaps the button's icon for a check
// for a moment so the click visibly did something.
export default class extends Controller {
  static targets = [ "source", "icon", "checkmark" ]
  static values = { resetAfter: { type: Number, default: 2000 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.showCheckmark(true)
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.showCheckmark(false), this.resetAfterValue)
  }

  showCheckmark(copied) {
    this.iconTarget.hidden = copied
    this.checkmarkTarget.hidden = !copied
  }
}
