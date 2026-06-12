import { Controller } from "@hotwired/stimulus"

// Dependent dropdown: choosing a lot repopulates the locker select with only
// the lockers that are currently available in that lot. These are plain native
// selects (not Choices-enhanced), so repopulating innerHTML is safe.
export default class extends Controller {
  static targets = ["lot", "locker"]
  static values = { url: String, current: String }

  loadLockers = async () => {
    const lotId = this.lotTarget.value
    this._setOptions(this.lockerTarget, [["Loading…", ""]], true)

    if (!lotId) {
      this._setOptions(this.lockerTarget, [["Select…", ""]], true)
      return
    }

    let params = `lot_id=${encodeURIComponent(lotId)}`
    // After the first manual change there's no longer a "current" locker to
    // preserve — only seed it on the very first load (edit screen).
    if (this.hasCurrentValue && this.currentValue) {
      params += `&current_locker_id=${encodeURIComponent(this.currentValue)}`
      this.currentValue = ""
    }

    try {
      const res = await fetch(`${this.urlValue}?${params}`, {
        headers: { Accept: "application/json" }
      })
      if (!res.ok) return
      const pairs = await res.json() // [[number, id], ...]

      if (pairs.length === 0) {
        this._setOptions(this.lockerTarget, [["No lockers available", ""]], true)
      } else {
        this._setOptions(this.lockerTarget, [["Select…", ""], ...pairs], false)
      }
    } catch (e) {
      this._setOptions(this.lockerTarget, [["Select…", ""]], true)
    }
  }

  _setOptions(select, pairs, disabled) {
    if (!select) return
    select.innerHTML = pairs
      .map(([text, value]) => `<option value="${value}">${text}</option>`)
      .join("")
    select.disabled = !!disabled
  }
}
