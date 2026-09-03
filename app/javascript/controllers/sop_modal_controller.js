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
    const scope = event.currentTarget.closest(".data-refresh-dsl-card, .dsl-sop-scope")
    this.activeBackdrop = scope?.querySelector("[data-sop-modal-target='backdrop']") || this.backdropTarget
    this.activeBackdrop.hidden = false
    document.addEventListener("keydown", this.keydown)
    this.activeBackdrop.querySelector(".pb-modal__close")?.focus()
  }

  async openReference(event) {
    event.preventDefault()
    const sopBackdrop = event.currentTarget.closest(".pb-modal-backdrop")
    const referenceBackdrop = sopBackdrop?.nextElementSibling
    if (!referenceBackdrop?.matches("[data-sop-reference]")) return

    this.referenceTrigger = event.currentTarget
    this.parentBackdrop = sopBackdrop
    this.activeBackdrop = referenceBackdrop
    referenceBackdrop.hidden = false
    document.addEventListener("keydown", this.keydown)
    referenceBackdrop.querySelector(".pb-modal__close")?.focus()

    const body = referenceBackdrop.querySelector("[data-sop-reference-body]")
    body.textContent = "Loading folder contents…"

    try {
      const response = await fetch(event.currentTarget.dataset.url, {
        headers: { Accept: "text/html" },
      })
      body.innerHTML = await response.text()
    } catch (_error) {
      body.textContent = "The folder contents could not be loaded."
    }
  }

  close() {
    if (!this.activeBackdrop) return

    this.activeBackdrop.hidden = true
    if (this.parentBackdrop) {
      this.activeBackdrop = this.parentBackdrop
      this.parentBackdrop = null
      this.referenceTrigger?.focus()
      this.referenceTrigger = null
      return
    }

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
