import { Controller } from "@hotwired/stimulus"
import hljs from "highlight.js/lib/core"
import ruby from "highlight.js/lib/languages/ruby"

hljs.registerLanguage("ruby", ruby)

export default class extends Controller {
  connect() {
    hljs.highlightElement(this.element)
  }
}
