// app/javascript/controllers/date_confirm_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "start", "end"]

  connect() {
    this.pendingButton = null
  }

  handleClick(event) {
    const btn = event.currentTarget
    // Skip if not a date-required action
    if (!btn.dataset.requiresDates) return

    // Prevent immediate confirm#open on first click
    if (btn.dataset.skipDate === "true") {
      // one-time bypass flag was set by continue()
      delete btn.dataset.skipDate
      return
    }

    event.preventDefault()
    this.pendingButton = btn
    this.open()
  }

  open() {
    this.backdropTarget.classList.add("open")
    // seed values if empty
    if (!this.startTarget.value) this.startTarget.value = this.defaultTodayStart()
    if (!this.endTarget.value) this.endTarget.value = this.defaultTodayEnd()
  }

  cancel() {
    this.backdropTarget.classList.remove("open")
    this.pendingButton = null
  }

  continue() {
    if (!this.pendingButton) return this.cancel()

    const form = this.pendingButton.closest("form")
    if (form) {
      const sField = form.querySelector("input[name='s_date']")
      const eField = form.querySelector("input[name='e_date']")
      if (sField && eField) {
        sField.value = this.startTarget.value
        eField.value = this.endTarget.value
      }
    }

    // Close date modal
    this.backdropTarget.classList.remove("open")

    // Now trigger the original button again, this time skipping the date step,
    // so your existing confirm#open will run exactly as before.
    this.pendingButton.dataset.skipDate = "true"
    this.pendingButton.click()
    // cleanup reference
    this.pendingButton = null
  }

  defaultTodayStart() {
    const d = new Date()
    d.setDate(1)
    return d.toISOString().slice(0,10)
  }

  defaultTodayEnd() {
    const d = new Date()
    d.setMonth(d.getMonth() + 1, 0)
    return d.toISOString().slice(0,10)
  }
}
