import { Controller } from "@hotwired/stimulus"

// Moving invoices on the AIM queues: tick one or several rows, then Move
// selected opens one dialog for them all. Modelled on reassign_modal_controller.
//
//   <div data-controller="aim-move-modal" data-aim-move-modal-bulk-url-value="/aim/invoices/reassign_many">
//     ... rows with data-aim-move-modal-target="check" boxes, the bulk bar, the modal ...
export default class extends Controller {
  static targets = ["backdrop", "form", "title", "owner", "person", "check", "bulkButton", "bulkCount", "ids",
                    "unitChoice", "unitMessage", "unitSelect", "unitHelp", "keepUnit"]
  static values = { bulkUrl: String }

  connect() {
    this.onPerson = () => this.personChanged()
    if (this.hasPersonTarget) this.personTarget.addEventListener("change", this.onPerson)
    this.onKey = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    this.onClick = (event) => { if (event.target === this.backdropTarget) this.close() }
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    if (this.hasPersonTarget) this.personTarget.removeEventListener("change", this.onPerson)
    document.removeEventListener("keydown", this.onKey)
    this.element.removeEventListener("click", this.onClick)
  }

  // Several at once: the ticked rows go as ids[] to the bulk move.
  openMany() {
    const ids = this.checked().map((box) => box.value)
    if (ids.length === 0) return
    this.formTarget.action = this.bulkUrlValue
    this.idsTarget.replaceChildren(...ids.map((id) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ids[]"
      input.value = id
      return input
    }))
    this.titleTarget.textContent = `Move ${ids.length} invoice${ids.length === 1 ? "" : "s"}`
    this.preparePeople()
    this.backdropTarget.hidden = false
    const search = this.element.querySelector(".aim-grouped-search__input")
    setTimeout(() => search?.focus(), 0)
  }

  // The person list puts the invoices' BU first when they share one, and
  // starts with nobody chosen.
  preparePeople() {
    if (!this.hasPersonTarget) return
    const units = [...new Set(this.checked().map((box) => box.dataset.budgetUnit || ""))]
    this.personTarget.dataset.priorityUnit = units.length === 1 ? units[0] : ""
    this.personTarget.dispatchEvent(new Event("aim-grouped-search:reset"))
    this.personChanged()
  }

  // The person's budget units are the groups they are listed under. If they
  // do not work in the ticked invoices' BU, the invoices take one of theirs
  // (chosen for you when they have only one), unless kept by exception.
  personChanged() {
    if (!this.hasUnitChoiceTarget) return
    const id = this.personTarget.value
    const theirs = id ? this.unitsOf(id) : []
    const units = [...new Set(this.checked().map((box) => box.dataset.budgetUnit || ""))].filter(Boolean)
    const outside = units.filter((unit) => !theirs.includes(unit))
    const show = Boolean(id) && outside.length > 0 && theirs.length > 0
    this.unitChoiceTarget.hidden = !show
    this.unitSelectTarget.required = show
    if (this.hasKeepUnitTarget) this.keepUnitTarget.checked = false
    if (!show) { this.unitSelectTarget.replaceChildren(); return }

    const name = this.personTarget.selectedOptions[0]?.text.replace(/\s*\(\d+\)$/, "") || "They"
    const bu = outside.join(", ")
    this.unitMessageTarget.textContent = `${name} does not work in ${bu}. Which of their budget units should it go to?`
    this.unitHelpTarget.textContent = `To keep it in ${bu}, ask an AIM Admin or ${bu}'s BU Admin to add them to ${bu}.`
    const options = (theirs.length > 1 ? [new Option("Pick a budget unit…", "")] : [])
      .concat(theirs.map((unit) => new Option(this.unitLabel(unit), unit)))
    this.unitSelectTarget.replaceChildren(...options)
    this.unitSelectTarget.value = theirs.length === 1 ? theirs[0] : ""
  }

  keepChanged() {
    const keep = this.keepUnitTarget.checked
    this.unitSelectTarget.disabled = keep
    this.unitSelectTarget.required = !keep
  }

  unitsOf(id) {
    return Array.from(this.personTarget.querySelectorAll("optgroup"))
      .filter((group) => group.dataset.unit && group.querySelector(`option[value="${id}"]`))
      .map((group) => group.dataset.unit)
  }

  unitLabel(unit) {
    return this.personTarget.querySelector(`optgroup[data-unit="${unit}"]`)?.label || unit
  }

  // A header box ticks or clears the rows in its table that the search shows.
  selectAll(event) {
    const table = event.currentTarget.closest("table")
    table.querySelectorAll("[data-aim-move-modal-target=check]").forEach((box) => {
      if (!box.closest("tr").hidden) box.checked = event.currentTarget.checked
    })
    this.count()
  }

  count() {
    const n = this.checked().length
    if (this.hasBulkCountTarget) this.bulkCountTarget.textContent = n
    if (this.hasBulkButtonTarget) this.bulkButtonTarget.disabled = n === 0
  }

  checked() {
    return this.checkTargets.filter((box) => box.checked && !box.closest("tr").hidden)
  }

  close() {
    this.backdropTarget.hidden = true
  }
}
