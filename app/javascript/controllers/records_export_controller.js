// app/javascript/controllers/records_export_controller.js
//
// The Records grid Export dialog (records/_export_modal): open and close it,
// and show the day field that matches the chosen schedule frequency.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "frequency", "weeklyField", "monthlyField"]

  connect() {
    this.escHandler = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.escHandler)
    this.frequencyChanged()
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

  // Only the field for the chosen frequency is shown and submitted; a hidden
  // field is disabled so a weekly schedule doesn't also post a day of month.
  frequencyChanged() {
    if (!this.hasFrequencyTarget) return

    const frequency = this.frequencyTarget.value
    this.toggleField(this.weeklyFieldTarget, frequency === "weekly")
    this.toggleField(this.monthlyFieldTarget, frequency === "monthly")
  }

  toggleField(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input, select").forEach((input) => {
      input.disabled = !visible
      input.required = visible
    })
  }
}
