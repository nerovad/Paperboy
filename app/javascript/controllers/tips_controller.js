// app/javascript/controllers/tips_controller.js
//
// The "Tips & Tricks" dialog behind the paperboy in the bottom-left corner.
//
// Opened by the `tips:open` window event rather than by an action wired to the
// mascot, for the reason Who Am I is: the dialog sits in the layout and the
// things that open it need not be anywhere near it. That leaves room for the
// sidebar search or the command palette to offer it later without either one
// having to reach the dialog.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.style.overflow = ""
  }

  open() {
    this.modalTarget.hidden = false
    document.body.style.overflow = "hidden"
    // Escape is bound on the document rather than the dialog so it works
    // before anything inside has been focused.
    document.addEventListener("keydown", this.closeOnEscape)
    this.modalTarget.querySelector(".pb-modal__close")?.focus()
  }

  close() {
    this.modalTarget.hidden = true
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  // Only a click on the backdrop itself dismisses; clicks that bubble up from
  // the dialog do not.
  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }
}
