import { Controller } from "@hotwired/stimulus"

// Moving invoices on the AIM queues: tick one or several rows, then Move
// selected opens one dialog for them all. Modelled on reassign_modal_controller.
//
//   <div data-controller="aim-move-modal" data-aim-move-modal-bulk-url-value="/aim/invoices/reassign_many">
//     ... rows with data-aim-move-modal-target="check" boxes, the bulk bar, the modal ...
export default class extends Controller {
  static targets = ["backdrop", "form", "title", "owner", "person", "check", "bulkButton", "bulkCount", "ids"]
  static values = { bulkUrl: String }

  connect() {
    this.onKey = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    this.onClick = (event) => { if (event.target === this.backdropTarget) this.close() }
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
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
