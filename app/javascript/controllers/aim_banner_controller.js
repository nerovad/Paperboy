import { Controller } from "@hotwired/stimulus"

// A notice on an invoice folds down to its title (#160), so several of them,
// or a long one, leave the invoice room. Its <strong> title becomes the
// toggle; the rest of the text hides, and any buttons beside it stay. Each
// kind of notice (by title) is remembered folded or open in this browser --
// best effort, as private windows may refuse storage.
export default class extends Controller {
  connect() {
    this.title = this.element.querySelector("strong")
    if (!this.title) return

    this.key = `aim-banner:${this.title.textContent.trim()}`
    this.title.classList.add("aim-readonly-banner__toggle")
    this.title.setAttribute("role", "button")
    this.title.setAttribute("tabindex", "0")
    this.onClick = () => this.toggle()
    this.onKey = (event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); this.toggle() } }
    this.title.addEventListener("click", this.onClick)
    this.title.addEventListener("keydown", this.onKey)
    let folded = false
    try { folded = window.localStorage.getItem(this.key) === "folded" } catch (_) { /* nothing kept */ }
    this.show(!folded)
  }

  disconnect() {
    if (!this.title) return
    this.title.removeEventListener("click", this.onClick)
    this.title.removeEventListener("keydown", this.onKey)
  }

  toggle() {
    const open = this.element.classList.contains("is-folded")
    this.show(open)
    try { window.localStorage.setItem(this.key, open ? "open" : "folded") } catch (_) { /* not kept */ }
  }

  show(open) {
    this.element.classList.toggle("is-folded", !open)
    this.title.setAttribute("aria-expanded", String(open))
  }
}
