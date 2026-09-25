import { Controller } from "@hotwired/stimulus"

// Where an invoice goes, on Upload and in the Move dialog: the person search
// shows only while "a person" / "Someone else" is chosen, and the budget unit
// list only while "another budget unit's shared queue" is.
export default class extends Controller {
  static targets = ["picker", "unit"]

  connect() {
    this.update()
  }

  update() {
    const chosen = this.element.querySelector("input[type=radio]:checked")?.value
    this.toggle(this.pickerTarget, chosen === "person", "input[type=search]")
    if (this.hasUnitTarget) this.toggle(this.unitTarget, chosen === "other_unit", "select")
  }

  toggle(target, shown, fieldSelector) {
    target.hidden = !shown
    const field = target.querySelector(fieldSelector)
    if (field) field.required = shown
  }
}
