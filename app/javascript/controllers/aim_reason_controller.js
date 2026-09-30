import { Controller } from "@hotwired/stimulus"

// Reject, Delete, Send Back, Restore and Fiscal's Hold ask why first. The
// dialog lives inside the page's form: opening it puts the action on its
// submit button and enables the reason box, so the reason is posted with the
// form. The button that opens it says what to post (data-value, the stable
// action name the controller dispatches on) apart from what to show
// (data-commit, the label); data-variant="approve" makes the submit button
// green rather than red. Closing it disables the box again, so Save Changes
// never carries a stale reason.
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
    const approve = trigger.dataset.variant === "approve"
    this.titleTarget.textContent = trigger.dataset.title || trigger.dataset.commit
    this.submitTarget.value = trigger.dataset.value
    this.submitTarget.textContent = trigger.dataset.commit
    this.submitTarget.classList.toggle("deny", !approve)
    this.submitTarget.classList.toggle("approve", approve)
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
