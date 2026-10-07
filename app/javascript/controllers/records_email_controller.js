// app/javascript/controllers/records_email_controller.js
//
// The Records grid Email dialog (records/_email_modal): open and close it,
// show the day field that matches a rule's frequency, and swap a rule's
// recipients box for a note about contacts when it splits by a column. The
// rule's condition fields are a records-condition controller.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "frequency", "weeklyField", "monthlyField", "split", "recipientsField", "splitHint"]

  connect() {
    this.escHandler = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.escHandler)
    this.frequencyChanged()
    this.splitChanged()
    this.forgetOpenParam()
  }

  disconnect() {
    document.removeEventListener("keydown", this.escHandler)
  }

  open() {
    this.backdropTarget.hidden = false
  }

  // Viewers without the edit grant have the controller but no dialog.
  close() {
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  // The server reopens the dialog after each change with ?email=open. Dropped
  // from the address bar so a refresh or a shared link shows the plain grid.
  forgetOpenParam() {
    const url = new URL(window.location.href)
    if (!url.searchParams.has("email")) return

    url.searchParams.delete("email")
    window.history.replaceState(window.history.state, "", url)
  }

  // Only the field for the chosen frequency is shown and submitted; a hidden
  // field is disabled so a weekly rule doesn't also post a day of month.
  frequencyChanged() {
    if (!this.hasFrequencyTarget) return

    const frequency = this.frequencyTarget.value
    this.toggleField(this.weeklyFieldTarget, frequency === "weekly")
    this.toggleField(this.monthlyFieldTarget, frequency === "monthly")
  }

  // A rule that splits by a column sends to that column's contacts, so it has
  // no recipients of its own.
  splitChanged() {
    if (!this.hasSplitTarget) return

    const split = this.splitTarget.value !== ""
    this.toggleField(this.recipientsFieldTarget, !split)
    this.splitHintTarget.hidden = !split
  }

  toggleField(field, visible) {
    field.hidden = !visible
    field.querySelectorAll("input, select, textarea").forEach((input) => {
      input.disabled = !visible
      input.required = visible
    })
  }
}
