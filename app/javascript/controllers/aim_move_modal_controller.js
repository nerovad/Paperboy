import { Controller } from "@hotwired/stimulus"

// The Move dialog on the AIM queues: one modal for the page, opened for the
// invoice whose Move button was pressed. Modelled on reassign_modal_controller.
//
//   <div data-controller="aim-move-modal">
//     <button data-action="aim-move-modal#open" data-url="/aim/invoices/ID/reassign?queue=..."
//             data-label="INV-1 from Jane Doe's queue">Move</button>
//     ... the modal (see aim/invoices/_move_modal) ...
export default class extends Controller {
  static targets = ["backdrop", "form", "title", "owner"]

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
    this.titleTarget.textContent = `Move ${trigger.dataset.label}`
    this.backdropTarget.hidden = false
    // The select is a Choices widget; focusing its search box is what a
    // person expects to type into.
    const search = this.element.querySelector(".choices__input--cloned")
    setTimeout(() => (search || this.ownerTarget).focus(), 0)
  }

  close() {
    this.backdropTarget.hidden = true
  }
}
