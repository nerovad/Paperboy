import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toggle"]

  toggle() {
    if (!this.hasContentTarget) return

    const expanded = this.contentTarget.hidden
    this.contentTarget.hidden = !expanded
    this.toggleTarget.setAttribute("aria-expanded", String(expanded))
  }
}
