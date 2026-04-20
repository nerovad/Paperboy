import { Controller } from "@hotwired/stimulus"

// Handles conditional field visibility on generated forms.
// Fields with data-depends-on and data-show-values show/hide based on
// the value of the trigger select. When the conditional field is inside
// a .vehicle-block (per-vehicle conditional), its scope is that block;
// otherwise the scope is the whole form.
export default class extends Controller {
  connect() {
    this.update = () => this.updateAll()

    this.element.addEventListener("change", this.update)
    this.element.addEventListener("addItem", this.update)
    this.element.addEventListener("removeItem", this.update)

    this.updateAll()
    this.setupConditionalAnswers()
  }

  disconnect() {
    this.element.removeEventListener("change", this.update)
    this.element.removeEventListener("addItem", this.update)
    this.element.removeEventListener("removeItem", this.update)
  }

  updateAll() {
    this.element.querySelectorAll(".conditional-field").forEach(el => {
      const dependsOn = el.dataset.dependsOn
      if (dependsOn) this.updateConditionalField(el, dependsOn)
    })
  }

  updateConditionalField(conditionalEl, dependsOn) {
    if (conditionalEl.closest("#vehicle-template")) return

    const scope = conditionalEl.closest(".vehicle-block") || this.element
    const triggerSelects = scope.querySelectorAll(
      `select[name$="[${dependsOn}]"], select[name$="[${dependsOn}][]"]`
    )

    const selectedValues = []
    triggerSelects.forEach(triggerSelect => {
      if (triggerSelect.closest("#vehicle-template")) return
      if (triggerSelect.multiple) {
        Array.from(triggerSelect.selectedOptions).forEach(o => selectedValues.push(o.value))
      } else if (triggerSelect.value) {
        selectedValues.push(triggerSelect.value)
      }
    })

    let showValues = []
    try {
      const rawValues = conditionalEl.dataset.showValues
      if (rawValues) {
        showValues = JSON.parse(rawValues.replace(/&quot;/g, '"'))
      }
    } catch (e) {
      console.error("Error parsing conditional values:", e)
      return
    }

    const shouldShow = selectedValues.some(v => showValues.includes(v))

    if (shouldShow) {
      conditionalEl.style.display = "block"
      conditionalEl.querySelectorAll("[data-was-required]").forEach(input => {
        input.required = true
      })
    } else {
      conditionalEl.style.display = "none"
      conditionalEl.querySelectorAll("input, select, textarea").forEach(input => {
        if (input.required) {
          input.dataset.wasRequired = "true"
          input.required = false
        }
      })
    }
  }

  setupConditionalAnswers() {
    const answerFields = this.element.querySelectorAll("[data-answer-depends-on]")

    answerFields.forEach(answerEl => {
      const dependsOn = answerEl.dataset.answerDependsOn
      if (!dependsOn) return

      const triggerSelect = this.element.querySelector(`select[name$="[${dependsOn}]"]`) ||
                            this.element.querySelector(`select[name$="[${dependsOn}][]"]`)
      if (!triggerSelect) return

      const targetSelect = answerEl.querySelector("select")
      if (!targetSelect) return

      const handler = () => this.updateConditionalAnswer(answerEl, triggerSelect, targetSelect)

      triggerSelect.addEventListener("change", handler)
      triggerSelect.addEventListener("addItem", handler)
      triggerSelect.addEventListener("removeItem", handler)
    })
  }

  updateConditionalAnswer(answerEl, triggerSelect, targetSelect) {
    let selectedValue
    if (triggerSelect.multiple) {
      const selected = Array.from(triggerSelect.selectedOptions).map(o => o.value)
      selectedValue = selected[0] || ""
    } else {
      selectedValue = triggerSelect.value || ""
    }

    if (!selectedValue) return

    let mappings = {}
    try {
      const rawMappings = answerEl.dataset.answerMappings
      if (rawMappings) {
        mappings = JSON.parse(rawMappings.replace(/&quot;/g, '"'))
      }
    } catch (e) {
      console.error("Error parsing conditional answer mappings:", e)
      return
    }

    const mappedAnswer = mappings[selectedValue]
    if (mappedAnswer) {
      targetSelect.value = mappedAnswer

      const selectName = targetSelect.getAttribute("name")
      if (selectName) {
        const hiddenField = this.element.querySelector(`input[type="hidden"][name="${selectName}"]`)
        if (hiddenField) {
          hiddenField.value = mappedAnswer
        }
      }

      targetSelect.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
