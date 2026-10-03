import { Controller } from "@hotwired/stimulus"

// Shows one panel at a time. The server renders the first panel visible and
// the rest hidden, so the page reads right before this connects.
export default class extends Controller {
  static targets = [ "tab", "panel" ]

  select({ params: { index } }) {
    this.tabTargets.forEach((tab, i) => tab.setAttribute("aria-selected", i === index))
    this.panelTargets.forEach((panel, i) => panel.hidden = i !== index)
  }
}
