import { Controller } from "@hotwired/stimulus"

// Closes the Users & Queues Actions menus (native <details>) on a click
// anywhere outside the open one, or on Escape. Opening one menu closing the
// others is the <details name=...> group's own doing, not this controller's.
// A menu opened too near the bottom of its scrolling list opens upward, so the
// list's edge doesn't cut it off.
export default class extends Controller {
  connect() {
    this.onClick = (event) => this.closeAll((menu) => !menu.contains(event.target))
    this.onKey = (event) => { if (event.key === "Escape") this.closeAll(() => true) }
    this.onToggle = (event) => this.place(event.target)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKey)
    this.element.addEventListener("toggle", this.onToggle, true)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKey)
    this.element.removeEventListener("toggle", this.onToggle, true)
  }

  place(menu) {
    if (!menu.matches?.("details.aim-actions-menu") || !menu.open) return
    const list = menu.querySelector(".aim-actions-menu__list")
    if (!list) return
    list.classList.remove("is-up")
    const scroller = menu.closest("[data-aim-queue-filter-target~=scroll]")
    const floor = scroller ? scroller.getBoundingClientRect().bottom : window.innerHeight
    const below = list.getBoundingClientRect().bottom
    const room = menu.getBoundingClientRect().top - (scroller ? scroller.getBoundingClientRect().top : 0)
    if (below > floor && room > list.offsetHeight) list.classList.add("is-up")
  }

  closeAll(shouldClose) {
    this.element.querySelectorAll("details.aim-actions-menu[open]").forEach((menu) => {
      if (shouldClose(menu)) menu.open = false
    })
  }
}
