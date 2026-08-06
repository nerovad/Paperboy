import { Controller } from "@hotwired/stimulus"
import { pbConfirm } from "pb_modal"

export default class extends Controller {
  static targets = ["button"]

  async confirm(event) {
    event.preventDefault()

    const proceed = await pbConfirm({
      title: "Delete form template",
      message: "This will delete the form template and all generated files. This cannot be undone.",
      confirmLabel: "Delete",
      confirmVariant: "deny"
    })
    if (!proceed) return

    // Show loading state on the button
    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = 'Deleting...'

    // Show loading overlay on the card
    const card = this.element.closest('.approver-card')
    if (card) {
      card.style.position = 'relative'
      const overlay = document.createElement('div')
      overlay.className = 'loading-overlay'
      overlay.innerHTML = `
        <div class="loading-spinner"></div>
        <span class="loading-text">Deleting form...</span>
      `
      card.appendChild(overlay)
    }

    // Submit the form
    this.element.requestSubmit()
  }
}
