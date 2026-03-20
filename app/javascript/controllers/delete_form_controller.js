import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  confirm(event) {
    event.preventDefault()

    if (!window.confirm("Are you sure? This will delete the form template and all generated files.")) {
      return
    }

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
