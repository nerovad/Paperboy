import { Controller } from "@hotwired/stimulus"

// Toggles the sidebar application-switcher dropdown and closes it on any
// outside click. Mirrors profile_dropdown_controller's outside-click pattern.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.boundOutsideClick = this.outsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
  }

  toggle(event) {
    event.stopPropagation()
    const isOpen = this.menuTarget.classList.toggle("show")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", isOpen ? "true" : "false")
    }
  }

  outsideClick(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }

  close() {
    this.menuTarget.classList.remove("show")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }
}
