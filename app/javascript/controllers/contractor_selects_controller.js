// app/javascript/controllers/contractor_selects_controller.js
//
// Cascading + searchable selects for the contractor admin forms:
//   Agency (plain select) → Unit (searchable) → Supervisor (searchable)
//
// Unit options are fetched for the chosen agency; supervisor options are
// fetched for the chosen unit. The unit/supervisor selects are enhanced with
// Choices.js for search, so options are swapped through the Choices API
// (setChoices) rather than by rewriting innerHTML, which Choices wouldn't see.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agency", "unit", "supervisor"]
  static values = {
    unitsUrl: { type: String, default: "/lookups/units" },
    supervisorsUrl: { type: String, default: "/lookups/supervisors" },
    currentUnit: String,
    currentSupervisor: String
  }

  connect() {
    this.unitChoices = this._enhance(this.unitTarget, "Search units…")
    this.supervisorChoices = this._enhance(this.supervisorTarget, "Search supervisors…")

    // Edit screen: agency already chosen → seed the dependent lists and
    // re-select the contractor's existing unit/supervisor.
    if (this.agencyTarget.value) {
      this._loadUnits(this.currentUnitValue).then(() => {
        if (this.unitTarget.value) this._loadSupervisors(this.currentSupervisorValue)
      })
    }
  }

  disconnect() {
    this.unitChoices?.destroy()
    this.supervisorChoices?.destroy()
  }

  agencyChanged() {
    this._resetSupervisor()
    this._loadUnits()
  }

  unitChanged() {
    this._loadSupervisors()
  }

  async _loadUnits(selectValue = "") {
    const agency = this.agencyTarget.value
    if (!agency) {
      this._setChoices(this.unitChoices, [], "", "Select an agency first")
      this._resetSupervisor()
      return
    }
    const pairs = await this._fetch(this.unitsUrlValue, { agency })
    this._setChoices(this.unitChoices, pairs, selectValue, "Search units…")
    if (!selectValue) this._resetSupervisor()
  }

  async _loadSupervisors(selectValue = "") {
    const unit = this.unitTarget.value
    if (!unit) {
      this._resetSupervisor()
      return
    }
    const pairs = await this._fetch(this.supervisorsUrlValue, { unit })
    this._setChoices(this.supervisorChoices, pairs, selectValue, "Search supervisors…")
  }

  _resetSupervisor() {
    this._setChoices(this.supervisorChoices, [], "", "Select a unit first")
  }

  async _fetch(url, params) {
    const u = new URL(url, window.location.origin)
    Object.entries(params).forEach(([k, v]) => u.searchParams.set(k, v))
    try {
      const res = await fetch(u, { headers: { Accept: "application/json" } })
      if (!res.ok) return []
      return await res.json() // [[label, value], ...]
    } catch (e) {
      console.error("[contractor-selects] fetch error:", e)
      return []
    }
  }

  _enhance(select, placeholder) {
    if (!window.Choices || !select) return null
    return new window.Choices(select, {
      removeItemButton: false,
      shouldSort: false,
      searchEnabled: true,
      allowHTML: false,
      itemSelectText: "",
      placeholder: true,
      placeholderValue: placeholder
    })
  }

  // Replace a Choices-enhanced select's options. Choices keeps the underlying
  // native <select> in sync, so the form still submits the chosen value.
  _setChoices(choices, pairs, selectValue = "", placeholder = "Select…") {
    if (!choices) return
    const options = pairs.map(([label, value]) => ({
      value: String(value),
      label,
      selected: selectValue !== "" && String(value) === String(selectValue)
    }))
    choices.clearStore()
    choices.setChoices(
      [{ value: "", label: placeholder, placeholder: true, selected: selectValue === "" }, ...options],
      "value",
      "label",
      true
    )
  }
}
