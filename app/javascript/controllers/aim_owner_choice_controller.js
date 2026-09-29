import { Controller } from "@hotwired/stimulus"

// Where an invoice goes, on Upload and in the Move dialog: the person search
// shows only while "a person" / "Someone else" is chosen, and the budget unit
// list only while "another budget unit's shared queue" is.
export default class extends Controller {
  static targets = ["picker", "unit", "person", "budgetUnit"]

  connect() {
    this.onPerson = () => this.personChanged()
    if (this.hasPersonTarget) this.personTarget.addEventListener("change", this.onPerson)
    this.update()
  }

  disconnect() {
    if (this.hasPersonTarget) this.personTarget.removeEventListener("change", this.onPerson)
  }

  // Upload: a person picked, the budget unit list offers only their BUs,
  // chosen for you when they have one (the BU follows the person,
  // 2026-09-29). Mine or the shared queue offers every BU again.
  personChanged() {
    if (!this.hasBudgetUnitTarget) return
    const chosen = this.element.querySelector("input[type=radio]:checked")?.value
    const id = chosen === "person" && this.hasPersonTarget ? this.personTarget.value : ""
    const theirs = id ? Array.from(this.personTarget.querySelectorAll("optgroup"))
      .filter((group) => group.dataset.unit && group.querySelector(`option[value="${id}"]`))
      .map((group) => group.dataset.unit) : []
    const select = this.budgetUnitTarget
    Array.from(select.options).forEach((option) => {
      if (option.value) option.disabled = theirs.length > 0 && !theirs.includes(option.value)
    })
    if (theirs.length && !theirs.includes(select.value)) select.value = theirs.length === 1 ? theirs[0] : ""
    select.dispatchEvent(new Event("aim-grouped-search:refresh"))
  }

  update() {
    this.personChanged()
    const chosen = this.element.querySelector("input[type=radio]:checked")?.value
    this.toggle(this.pickerTarget, chosen === "person", "select, input[type=search]")
    if (this.hasUnitTarget) this.toggle(this.unitTarget, chosen === "other_unit", "select")
  }

  toggle(target, shown, fieldSelector) {
    target.hidden = !shown
    const field = target.querySelector(fieldSelector)
    if (field) field.required = shown
  }
}
