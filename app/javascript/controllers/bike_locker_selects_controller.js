import { Controller } from "@hotwired/stimulus"

// Dependent dropdown: choosing a lot repopulates the locker select with only
// the lockers currently available in that lot.
//
// The controller is attached directly to the LOT <select> (not a wrapping div)
// so it survives Paperboy Form Builder regeneration — the builder rewrites the
// structural form-row/form-page wrappers but preserves the markup inside each
// <!-- FIELD --> block verbatim. The locker <select> lives in a sibling FIELD
// block, so it's found by id rather than as a Stimulus target. Both are plain
// native selects (not Choices-enhanced), so repopulating innerHTML is safe.
export default class extends Controller {
  static values = { url: String, current: String }

  loadLockers = async () => {
    const lotId = this.element.value
    const locker = this.lockerSelect
    this._setOptions(locker, [["Loading…", ""]], true)

    if (!lotId) {
      this._setOptions(locker, [["Select…", ""]], true)
      return
    }

    let params = `lot_id=${encodeURIComponent(lotId)}`
    // Only seed the already-chosen locker on the first load (edit screen);
    // after a manual lot change there's nothing to preserve.
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
        this._setOptions(locker, [["No lockers available", ""]], true)
      } else {
        this._setOptions(locker, [["Select…", ""], ...pairs], false)
      }
    } catch (e) {
      this._setOptions(locker, [["Select…", ""]], true)
    }
  }

  get lockerSelect() {
    return document.getElementById("bike-locker-number-select")
  }

  _setOptions(select, pairs, disabled) {
    if (!select) return
    select.innerHTML = pairs
      .map(([text, value]) => `<option value="${value}">${text}</option>`)
      .join("")
    select.disabled = !!disabled
  }
}
