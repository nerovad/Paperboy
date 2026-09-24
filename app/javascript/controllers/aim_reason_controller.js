import { Controller } from "@hotwired/stimulus"

// Reject, Delete and Send Back ask why first. The dialog lives inside the
// review form: opening it names the action on its submit button and enables
// the reason box, so the reason is posted with the form. Closing it disables
// the box again, so Save Changes never carries a stale reason.
export default class extends Controller {
  static targets = ["backdrop", "title", "reason", "submit"]

  connect() {
    this.onKey = (event) => { if (event.key === "Escape" && !this.backdropTarget.hidden) this.close() }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  open(event) {
    const trigger = event.currentTarget
    this.titleTarget.textContent = trigger.dataset.title || trigger.dataset.commit
    this.submitTarget.value = trigger.dataset.commit
    this.submitTarget.textContent = trigger.dataset.commit
    this.reasonTarget.disabled = false
    this.reasonTarget.required = true
    this.reasonTarget.value = ""
    this.backdropTarget.hidden = false
    setTimeout(() => this.reasonTarget.focus(), 0)
  }

  close() {
    this.backdropTarget.hidden = true
    this.reasonTarget.required = false
    this.reasonTarget.disabled = true
  }
}
