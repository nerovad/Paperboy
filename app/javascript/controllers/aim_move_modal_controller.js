import { Controller } from "@hotwired/stimulus"

// The Move dialog on the AIM queues: one modal for the page, opened for the
// invoice whose Move button was pressed. Modelled on reassign_modal_controller.
//
//   <div data-controller="aim-move-modal">
//     <button data-action="aim-move-modal#open" data-url="/aim/invoices/ID/reassign?queue=..."
//             data-label="INV-1 from Jane Doe's queue">Move</button>
//     ... the modal (see aim/invoices/_move_modal) ...
export default class extends Controller {
  static targets = ["backdrop", "form", "title", "owner", "check", "bulkButton", "bulkCount", "ids"]
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

  open(event) {
    const trigger = event.currentTarget
    this.formTarget.action = trigger.dataset.url
    this.idsTarget.replaceChildren()
    this.titleTarget.textContent = `Move ${trigger.dataset.label}`
    this.backdropTarget.hidden = false
    // The select is a Choices widget; focusing its search box is what a
    // person expects to type into.
    const search = this.element.querySelector(".choices__input--cloned")
    setTimeout(() => (search || this.ownerTarget).focus(), 0)
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
    this.backdropTarget.hidden = false
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
