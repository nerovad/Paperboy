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

  // The trigger is #profile-toggle when signed in and .login-toggle when
  // signed out; both carry aria-expanded, so match on that rather than on id.
  get toggleButton() {
    return this.element.querySelector("[aria-expanded]")
  }

  toggle(event) {
    event.stopPropagation()

    // Toggle visibility
    this.dropdownTarget.classList.toggle("show")

    // Optional: rotate chevron
    const isOpen = this.dropdownTarget.classList.contains("show")
    this.toggleButton?.setAttribute("aria-expanded", isOpen ? "true" : "false")
  }

  outsideClick(event) {
    // If click is inside the controller element (button OR dropdown), ignore
    if (this.element.contains(event.target)) return

    // Otherwise close menu
    this.dropdownTarget.classList.remove("show")

    // Reset chevron
    this.toggleButton?.setAttribute("aria-expanded", "false")
  }
}
