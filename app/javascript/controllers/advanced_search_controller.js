// app/javascript/controllers/advanced_search_controller.js
//
// The Advanced Search panel in the Paperboy sidebar.
//
// The org selects are the shared cascade — see org_cascade_controller.js, which
// this extends. All that is added here is opening and closing the dialog.
import OrgCascadeController from "controllers/org_cascade_controller"

export default class extends OrgCascadeController {
  static targets = ["modal"]

  connect() {
    super.connect()
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
    this.modalTarget.querySelector("input, select")?.focus()
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
  // the panel are the user working inside the form.
  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }
}
