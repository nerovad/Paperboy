import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["backdrop", "title", "grid"]
  static values = { slideshowUrl: String }

  select(event) {
    this.titleTarget.textContent = event.params.label
    this.gridTarget.src = event.params.url
    this.backdropTarget.hidden = false
  }

  dismiss() {
    this.backdropTarget.hidden = true
    if (this.hasGridTarget) {
      this.gridTarget.removeAttribute("src")
      this.gridTarget.replaceChildren()
    }
    if (this.slideshowUrlValue) Turbo.visit(this.slideshowUrlValue)
  }
}
