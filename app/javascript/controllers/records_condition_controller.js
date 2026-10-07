// app/javascript/controllers/records_condition_controller.js
//
// A "column meets condition" form on a Records grid, used by the Highlights
// dialog and the Email dialog's rules (see RecordsCondition): offer only the
// conditions that fit the chosen column (date conditions for a date column,
// text ones otherwise), and shape the value input for the chosen condition --
// a date, a number of days, text, or nothing at all for "is blank".
import { Controller } from "@hotwired/stimulus"

const DATE_KINDS = ["date", "datetime"]

export default class extends Controller {
  static targets = ["column", "operator", "valueField", "valueLabel", "value"]

  connect() {
    if (this.hasColumnTarget) this.columnChanged()
  }

  columnChanged() {
    const kind = this.columnTarget.selectedOptions[0]?.dataset.kind
    const fits = DATE_KINDS.includes(kind) ? "date" : "text"
    let firstFit = null

    Array.from(this.operatorTarget.options).forEach((option) => {
      const ok = option.dataset.applies === "any" || option.dataset.applies === fits
      option.hidden = !ok
      option.disabled = !ok
      if (ok && !firstFit) firstFit = option
    })
    if (this.operatorTarget.selectedOptions[0]?.disabled) this.operatorTarget.value = firstFit?.value
    this.operatorChanged()
  }

  operatorChanged() {
    const operator = this.operatorTarget.value
    const applies = this.operatorTarget.selectedOptions[0]?.dataset.applies
    const input = this.valueTarget

    this.valueFieldTarget.hidden = operator === "blank"
    input.disabled = operator === "blank"
    input.required = operator !== "blank"

    if (operator === "older_than_days") {
      this.setInput("number", "Days")
      input.min = "1"
    } else if (applies === "date") {
      this.setInput("date", "Date")
    } else {
      this.setInput("text", "Value")
    }
  }

  setInput(type, label) {
    if (this.valueTarget.type !== type) {
      this.valueTarget.type = type
      this.valueTarget.value = ""
    }
    this.valueTarget.removeAttribute("min")
    this.valueLabelTarget.textContent = label
  }
}
