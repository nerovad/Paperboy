import { Controller } from "@hotwired/stimulus"

// Handles conditional field visibility on generated forms
// Fields with data-depends-on and data-show-values attributes will show/hide
// based on the value of the trigger dropdown
export default class extends Controller {
  connect() {
    this.setupConditionalFields()
  }

  setupConditionalFields() {
    // Find all conditional fields
    const conditionalFields = this.element.querySelectorAll('.conditional-field')

    conditionalFields.forEach(conditionalEl => {
      const dependsOn = conditionalEl.dataset.dependsOn
      if (!dependsOn) return

      // Find the trigger select by field name
      const triggerSelect = this.element.querySelector(`select[name$="[${dependsOn}]"]`)
      if (!triggerSelect) return

      // Add change listener
      triggerSelect.addEventListener('change', () => {
        this.updateConditionalField(conditionalEl, triggerSelect)
      })

      // Initial check
      this.updateConditionalField(conditionalEl, triggerSelect)
    })
  }

  updateConditionalField(conditionalEl, triggerSelect) {
    const triggerValue = triggerSelect.value
    let showValues = []

    try {
      // Parse the show-values data attribute (may be HTML-encoded)
      const rawValues = conditionalEl.dataset.showValues
      if (rawValues) {
        showValues = JSON.parse(rawValues.replace(/&quot;/g, '"'))
      }
    } catch (e) {
      console.error('Error parsing conditional values:', e)
      return
    }

    if (showValues.includes(triggerValue)) {
      conditionalEl.style.display = 'block'
      // Re-enable required validation for inputs inside
      conditionalEl.querySelectorAll('[data-was-required]').forEach(input => {
        input.required = true
      })
    } else {
      conditionalEl.style.display = 'none'
      // Disable required validation and optionally clear values
      conditionalEl.querySelectorAll('input, select, textarea').forEach(input => {
        if (input.required) {
          input.dataset.wasRequired = 'true'
          input.required = false
        }
      })
    }
  }
}
