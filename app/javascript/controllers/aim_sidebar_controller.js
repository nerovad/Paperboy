import { Controller } from "@hotwired/stimulus"

// AIM's sidebar groups. AIM is open by default and the others closed; the
// group holding the current page is always open. A group you open or close
// yourself stays that way as you move between AIM pages, and the AIM main
// page puts them all back to the defaults. Kept per browser tab
// (sessionStorage); without storage, the defaults simply apply.
const KEY = "aim-sidebar-groups"

export default class extends Controller {
  static targets = ["group"]
  static values = { reset: Boolean }

  connect() {
    if (this.resetValue) this.save({})
    const chosen = this.load()
    this.groupTargets.forEach((group) => {
      const key = group.dataset.key
      if (group.dataset.current === "true") {
        group.open = true
      } else if (key in chosen) {
        group.open = chosen[key]
      } else {
        group.open = group.dataset.defaultOpen === "true"
      }
      group.addEventListener("toggle", () => this.remember(group))
    })
  }

  // Every open and close you make is kept -- the current page's group too.
  // Skipping that one left an older "open" in storage, which reopened the
  // group on the next page after you had just closed it.
  remember(group) {
    const chosen = this.load()
    chosen[group.dataset.key] = group.open
    this.save(chosen)
  }

  load() {
    try {
      const value = JSON.parse(sessionStorage.getItem(KEY) || "{}")
      return value && typeof value === "object" && !Array.isArray(value) ? value : {}
    } catch {
      return {}
    }
  }

  save(chosen) {
    try {
      sessionStorage.setItem(KEY, JSON.stringify(chosen))
    } catch {
      // Storage refused (private mode, blocked): the defaults apply.
    }
  }
}
