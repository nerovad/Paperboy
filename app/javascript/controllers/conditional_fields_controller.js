import { Controller } from "@hotwired/stimulus"

// Handles conditional field visibility on generated forms
// Fields with data-depends-on and data-show-values attributes will show/hide
// based on the value of the trigger dropdown
export default class extends Controller {
  connect() {
    this.setupConditionalFields()
    this.setupConditionalAnswers()
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

  setupConditionalAnswers() {
    // Find all fields with conditional answer mappings
    const answerFields = this.element.querySelectorAll('[data-answer-depends-on]')

    answerFields.forEach(answerEl => {
      const dependsOn = answerEl.dataset.answerDependsOn
      if (!dependsOn) return

      // Find the trigger select
      const triggerSelect = this.element.querySelector(`select[name$="[${dependsOn}]"]`) ||
                            this.element.querySelector(`select[name$="[${dependsOn}][]"]`)
      if (!triggerSelect) return

      // Find the target select inside this element
      const targetSelect = answerEl.querySelector('select')
      if (!targetSelect) return

      const handler = () => this.updateConditionalAnswer(answerEl, triggerSelect, targetSelect)

      triggerSelect.addEventListener('change', handler)
      triggerSelect.addEventListener('addItem', handler)
      triggerSelect.addEventListener('removeItem', handler)
    })
  }

  updateConditionalAnswer(answerEl, triggerSelect, targetSelect) {
    let selectedValue
    if (triggerSelect.multiple) {
      // For multi-select, use the first selected value for mapping
      const selected = Array.from(triggerSelect.selectedOptions).map(o => o.value)
      selectedValue = selected[0] || ''
    } else {
      selectedValue = triggerSelect.value || ''
    }

    if (!selectedValue) return

    let mappings = {}
    try {
      const rawMappings = answerEl.dataset.answerMappings
      if (rawMappings) {
        mappings = JSON.parse(rawMappings.replace(/&quot;/g, '"'))
      }
    } catch (e) {
      console.error('Error parsing conditional answer mappings:', e)
      return
    }

    const mappedAnswer = mappings[selectedValue]
    if (mappedAnswer) {
      targetSelect.value = mappedAnswer

      // Trigger change event so other listeners (Choices.js, other conditionals) pick it up
      targetSelect.dispatchEvent(new Event('change', { bubbles: true }))
    }
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
