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

    // Table-lookup targets are grouped by their trigger so one selection change
    // fires a single request that fills every field keyed off that trigger.
    const lookupGroups = {}

    answerFields.forEach(answerEl => {
      const dependsOn = answerEl.dataset.answerDependsOn
      if (!dependsOn) return

      const triggerSelect = this.element.querySelector(`select[name$="[${dependsOn}]"]`) ||
                            this.element.querySelector(`select[name$="[${dependsOn}][]"]`)
      if (!triggerSelect) return

      if (answerEl.dataset.answerLookupFieldId) {
        if (!lookupGroups[dependsOn]) lookupGroups[dependsOn] = { triggerSelect, targets: [] }
        lookupGroups[dependsOn].targets.push(answerEl)
        return
      }

      // Static value -> value mapping (dropdown targets only)
      const targetSelect = answerEl.querySelector("select")
      if (!targetSelect) return

      const handler = () => this.updateConditionalAnswer(answerEl, triggerSelect, targetSelect)

      triggerSelect.addEventListener("change", handler)
      triggerSelect.addEventListener("addItem", handler)
      triggerSelect.addEventListener("removeItem", handler)
    })

    Object.values(lookupGroups).forEach(({ triggerSelect, targets }) => {
      const handler = () => this.updateAnswerLookups(triggerSelect, targets)
      triggerSelect.addEventListener("change", handler)
      triggerSelect.addEventListener("addItem", handler)
      triggerSelect.addEventListener("removeItem", handler)
    })
  }

  // Fetch DB values for all lookup targets sharing a trigger and fill them in.
  // Fields stay editable — we only set the value and fire change.
  async updateAnswerLookups(triggerSelect, targets) {
    let value
    if (triggerSelect.multiple) {
      const selected = Array.from(triggerSelect.selectedOptions).map(o => o.value)
      value = selected[0] || ""
    } else {
      value = triggerSelect.value || ""
    }
    if (!value) return

    const params = new URLSearchParams()
    params.set("value", value)
    const byId = {}
    targets.forEach(el => {
      const id = el.dataset.answerLookupFieldId
      params.append("field_ids[]", id)
      byId[id] = el
    })

    try {
      const res = await fetch(`/lookups/answer_fill?${params.toString()}`)
      if (!res.ok) return
      const fills = await res.json()
      Object.keys(fills).forEach(id => {
        const el = byId[id]
        if (!el) return
        const input = el.querySelector("input, select, textarea")
        if (!input) return
        input.value = fills[id]
        input.dispatchEvent(new Event("change", { bubbles: true }))
      })
    } catch (e) {
      console.error("Answer lookup failed:", e)
    }
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
