import { Controller } from "@hotwired/stimulus"

// Closes the Users & Queues Actions menus (native <details>) on a click
// anywhere outside the open one, or on Escape. Opening one menu closing the
// others is the <details name=...> group's own doing, not this controller's.
export default class extends Controller {
  connect() {
    this.onClick = (event) => this.closeAll((menu) => !menu.contains(event.target))
    this.onKey = (event) => { if (event.key === "Escape") this.closeAll(() => true) }
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKey)
  }

  closeAll(shouldClose) {
    this.element.querySelectorAll("details.aim-actions-menu[open]").forEach((menu) => {
      if (shouldClose(menu)) menu.open = false
    })
  }
}
