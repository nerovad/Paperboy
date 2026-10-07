// app/javascript/controllers/records_highlights_controller.js
//
// The Records grid Highlights dialog (records/_highlight_rules_modal): open
// and close it. Its "add a rule" form is a records-condition controller.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    this.escHandler = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.escHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.escHandler)
  }

  open() {
    this.backdropTarget.hidden = false
  }

  close() {
    this.backdropTarget.hidden = true
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }
}
