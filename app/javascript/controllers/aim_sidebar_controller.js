import { Controller } from "@hotwired/stimulus"

// AIM's sidebar groups are all open unless you close one. A group you close
// stays closed as you move between AIM pages, and the AIM main page opens
// them all again. Kept per browser tab (sessionStorage); if storage is not
// available the groups simply stay open.
const KEY = "aim-sidebar-closed"

export default class extends Controller {
  static targets = ["group"]
  static values = { reset: Boolean }

  connect() {
    if (this.resetValue) this.save([])
    const closed = this.load()
    this.groupTargets.forEach((group) => {
      group.open = !closed.includes(group.dataset.key)
      group.addEventListener("toggle", () => this.remember())
    })
  }

  remember() {
    this.save(this.groupTargets.filter((group) => !group.open).map((group) => group.dataset.key))
  }

  load() {
    try {
      return JSON.parse(sessionStorage.getItem(KEY) || "[]")
    } catch {
      return []
    }
  }

  save(keys) {
    try {
      sessionStorage.setItem(KEY, JSON.stringify(keys))
    } catch {
      // Storage refused (private mode, blocked): the groups just stay open.
    }
  }
}
