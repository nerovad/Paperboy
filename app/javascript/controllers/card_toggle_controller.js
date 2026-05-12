// app/javascript/controllers/card_toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "form"]

  edit(event) {
    event?.preventDefault()
    if (this.hasCardTarget) this.cardTarget.hidden = true
    if (this.hasFormTarget) this.formTarget.hidden = false
  }

  collapse(event) {
    event?.preventDefault()
    if (this.hasFormTarget) this.formTarget.hidden = true
    if (this.hasCardTarget) this.cardTarget.hidden = false
  }
}
