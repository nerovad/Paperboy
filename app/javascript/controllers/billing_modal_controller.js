import { Controller } from "@hotwired/stimulus"

// data-controller="billing-modal"
export default class extends Controller {
  static targets = ["backdrop", "title", "message", "dateRow", "start", "end"]

  connect() {
    this.pendingButton = null
    // Defaults if inputs are empty
    this.defaultStart = this.#firstOfThisMonth()
    this.defaultEnd   = this.#lastOfThisMonth()
  }

  // Hooked by buttons: data-action="click->billing-modal#open"
  open(event) {
    const btn = event.currentTarget
    event.preventDefault() // stop the form for now

    this.pendingButton = btn

    // Title & message from button data (fallbacks just in case)
    this.titleTarget.textContent = btn.dataset.confirmTitle || "Confirm"
    this.messageTarget.textContent = btn.dataset.confirmMessage || "Are you sure?"

    // Toggle date row
    const needsDates = this.#needsDates(btn)
    this.dateRowTarget.style.display = needsDates ? "" : "none"

    // Prefill date inputs (use server-provided value if present in value attributes,
    // otherwise fallback JS defaults)
    if (!this.startTarget.value) this.startTarget.value = this.defaultStart
    if (!this.endTarget.value)   this.endTarget.value   = this.defaultEnd

    // Show modal
    this.backdropTarget.classList.add("open")
  }

  cancel() {
    this.backdropTarget.classList.remove("open")
    this.pendingButton = null
  }

  proceed() {
    if (!this.pendingButton) return this.cancel()

    const form = this.pendingButton.closest("form")
    if (form) {
      if (this.#needsDates(this.pendingButton)) {
        // Write dates to existing hidden fields in the form
        const sField = form.querySelector("input[name='s_date']")
        const eField = form.querySelector("input[name='e_date']")
        if (sField) sField.value = this.startTarget.value || this.defaultStart
        if (eField) eField.value = this.endTarget.value   || this.defaultEnd
      }
      // Submit the form now
      form.submit()
    }
    this.cancel()
  }

  #needsDates(btn) {
    return btn.dataset.requiresDates === "true"
  }

  #firstOfThisMonth() {
    const d = new Date()
    d.setDate(1)
    return d.toISOString().slice(0,10)
  }
  #lastOfThisMonth() {
    const d = new Date()
    d.setMonth(d.getMonth() + 1, 0)
    return d.toISOString().slice(0,10)
  }
}
