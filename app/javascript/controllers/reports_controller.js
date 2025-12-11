// app/javascript/controllers/reports_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusSelect", "statusGroup"]

  connect() {
    // Load status options if form is already selected (e.g., after validation error)
    const formSelect = this.element.querySelector('select[name="form_type"]')
    if (formSelect && formSelect.value) {
      this.loadStatusOptions({ target: formSelect })
    }
  }

  loadStatusOptions(event) {
    const formType = event.target.value

    if (!formType) {
      // Clear status options if no form selected
      this.clearStatusOptions()
      return
    }

    // Fetch status options for this form type
    fetch(`/reports/status_options?form_type=${encodeURIComponent(formType)}`)
      .then(response => response.json())
      .then(data => {
        this.updateStatusOptions(data.status_options)
      })
      .catch(error => {
        console.error('Error loading status options:', error)
        this.clearStatusOptions()
      })
  }

  updateStatusOptions(options) {
    const select = this.statusSelectTarget

    // Clear existing options except prompt
    select.innerHTML = '<option value="">All statuses</option>'

    // Add new options
    options.forEach(option => {
      const optionElement = document.createElement('option')
      optionElement.value = option.value
      optionElement.textContent = option.label
      select.appendChild(optionElement)
    })

    // Show the status group
    this.statusGroupTarget.style.display = 'block'
  }

  clearStatusOptions() {
    const select = this.statusSelectTarget
    select.innerHTML = '<option value="">All statuses</option>'
  }
}
