import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    document.addEventListener("click", this.handleDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("show")
  }

  handleDocumentClick = () => {
    this.dropdownTarget.classList.remove("show")
  }
}
