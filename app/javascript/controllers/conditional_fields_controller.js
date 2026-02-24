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

      // Find the trigger select by field name (also handles multi-select where Rails appends [])
      const triggerSelect = this.element.querySelector(`select[name$="[${dependsOn}]"]`) ||
                            this.element.querySelector(`select[name$="[${dependsOn}][]"]`)
      if (!triggerSelect) return

      const handler = () => this.updateConditionalField(conditionalEl, triggerSelect)

      // Add change listener
      triggerSelect.addEventListener('change', handler)
      // Also listen for Choices.js events (for multi-select dropdowns)
      triggerSelect.addEventListener('addItem', handler)
      triggerSelect.addEventListener('removeItem', handler)

      // Initial check
      handler()
    })
  }

  updateConditionalField(conditionalEl, triggerSelect) {
    // Support both single-select and multi-select triggers
    let selectedValues
    if (triggerSelect.multiple) {
      selectedValues = Array.from(triggerSelect.selectedOptions).map(o => o.value)
    } else {
      selectedValues = triggerSelect.value ? [triggerSelect.value] : []
    }

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

    const shouldShow = selectedValues.some(v => showValues.includes(v))

    if (shouldShow) {
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
