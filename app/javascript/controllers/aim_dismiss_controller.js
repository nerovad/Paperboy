import { Controller } from "@hotwired/stimulus"

// A dialog drawn into the page by the server (the Fiscal report preview,
// #131): Close or Escape takes it away again.
export default class extends Controller {
  connect() {
    this.onKey = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  close() {
    this.element.remove()
  }
}
