// app/javascript/controllers/who_am_i_controller.js
//
// The "Who Am I" dialog.
//
// It sits in the layout, out of reach of everything that opens it — the
// sidebar's search box on Paperboy pages, the command palette everywhere — so
// it is opened by the `who-am-i:open` window event rather than by an action
// wired to any one of them. The hierarchy inside is a lazy turbo-frame, which
// fetches the first time the backdrop is revealed and is reused after that.
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
