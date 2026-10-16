import { Controller } from "@hotwired/stimulus"

// A notice on an invoice folds down to its title (#160), so several of them,
// or a long one, leave the invoice room. The server renders it folded, with
// its title as the toggle (Aim::InvoicesHelper#aim_notice_title), so nothing
// moves once the page has loaded; this only opens and folds it again. Every
// notice starts folded on every page load (Joshua, 2026-10-16).
export default class extends Controller {
  toggle() {
    const open = this.element.classList.toggle("is-folded") === false
    this.element.querySelector(".aim-readonly-banner__toggle")?.setAttribute("aria-expanded", String(open))
  }

  key(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    event.preventDefault()
    this.toggle()
  }
}
