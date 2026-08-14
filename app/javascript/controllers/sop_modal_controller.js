import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    this.keydown = this.keydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
  }

  open(event) {
    event.preventDefault()
    this.previouslyFocused = event.currentTarget
    const card = event.currentTarget.closest(".billing-refresh-dsl-card")
    this.activeBackdrop = card?.querySelector("[data-sop-modal-target='backdrop']") || this.backdropTarget
    this.activeBackdrop.hidden = false
    document.addEventListener("keydown", this.keydown)
    this.activeBackdrop.querySelector(".pb-modal__close")?.focus()
  }

  close() {
    if (!this.activeBackdrop) return

    this.activeBackdrop.hidden = true
    this.activeBackdrop = null
    document.removeEventListener("keydown", this.keydown)
    this.previouslyFocused?.focus()
  }

  backdropClose(event) {
    if (event.target === this.activeBackdrop) this.close()
  }

  keydown(event) {
    if (event.key !== "Escape") return

    event.preventDefault()
    this.close()
  }
}
