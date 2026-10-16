import { Controller } from "@hotwired/stimulus"

// A notice on an invoice folds down to its title (#160), so several of them,
// or a long one, leave the invoice room. Its title (the first <strong> or
// <h3>, as on the Invoice panel's reason note) becomes the
// toggle, with a caret and, while folded, "Expand"; the rest of the text
// hides, and any buttons beside it stay. Every notice starts folded on every
// page load (Joshua, 2026-10-16); nothing is remembered.
export default class extends Controller {
  connect() {
    this.title = this.element.querySelector("strong, h3")
    if (!this.title) return

    this.title.classList.add("aim-readonly-banner__toggle")
    this.title.setAttribute("role", "button")
    this.title.setAttribute("tabindex", "0")
    this.title.insertAdjacentHTML("beforeend",
      '<span class="aim-readonly-banner__caret" aria-hidden="true"></span><span class="aim-readonly-banner__hint">Expand</span>')
    this.onClick = () => this.toggle()
    this.onKey = (event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); this.toggle() } }
    this.title.addEventListener("click", this.onClick)
    this.title.addEventListener("keydown", this.onKey)
    this.show(false)
  }

  disconnect() {
    if (!this.title) return
    this.title.removeEventListener("click", this.onClick)
    this.title.removeEventListener("keydown", this.onKey)
  }

  toggle() {
    const open = this.element.classList.contains("is-folded")
    this.show(open)
  }

  show(open) {
    this.element.classList.toggle("is-folded", !open)
    this.title.setAttribute("aria-expanded", String(open))
  }
}
