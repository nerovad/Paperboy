import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["backdrop", "title", "message"]
  static values = { slideshowUrl: String }

  select(event) {
    const label = event.params.label

    this.titleTarget.textContent = label
    this.messageTarget.textContent = `${label} button was pushed.`
    this.backdropTarget.hidden = false
  }

  dismiss() {
    this.backdropTarget.hidden = true
    if (this.slideshowUrlValue) Turbo.visit(this.slideshowUrlValue)
  }
}
