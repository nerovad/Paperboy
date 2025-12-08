import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    // Bind once so the reference stays consistent
    this.boundOutsideClick = this.outsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()

    // Toggle visibility
    this.dropdownTarget.classList.toggle("show")

    // Optional: rotate chevron
    const isOpen = this.dropdownTarget.classList.contains("show")
    this.element.querySelector("#profile-toggle")
      ?.setAttribute("aria-expanded", isOpen ? "true" : "false")
  }

  outsideClick(event) {
    // If click is inside the controller element (button OR dropdown), ignore
    if (this.element.contains(event.target)) return

    // Otherwise close menu
    this.dropdownTarget.classList.remove("show")

    // Reset chevron
    this.element.querySelector("#profile-toggle")
      ?.setAttribute("aria-expanded", "false")
  }
}
