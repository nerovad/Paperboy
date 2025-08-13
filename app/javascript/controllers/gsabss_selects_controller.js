// app/javascript/controllers/gsabss_selects_controller.js
import { Controller } from "@hotwired/stimulus"
import * as Turbo from "@hotwired/turbo"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]

  loadDivisions = async () => {
    this._prepLoad(this.divisionTarget, [this.departmentTarget, this.unitTarget])
    await this._fetchAndRender(`/lookups/divisions?agency=${encodeURIComponent(this.agencyTarget.value)}`)
    this.divisionTarget.disabled = false
  }

  loadDepartments = async () => {
    this._prepLoad(this.departmentTarget, [this.unitTarget])
    await this._fetchAndRender(`/lookups/departments?division=${encodeURIComponent(this.divisionTarget.value)}`)
    this.departmentTarget.disabled = false
  }

  loadUnits = async () => {
    this._prepLoad(this.unitTarget, [])
    await this._fetchAndRender(`/lookups/units?department=${encodeURIComponent(this.departmentTarget.value)}`)
    this.unitTarget.disabled = false
  }

  _prepLoad(primary, downstreamToClear = []) {
    // disable the primary and show a loading placeholder
    this._setOptions(primary, [["", "Loading…"]], true)
    // clear & disable all downstream selects
    downstreamToClear.forEach(sel => this._setOptions(sel, [["", "Select one"]], true))
  }

  _setOptions(select, pairs, disabled) {
    if (!select) return
    select.innerHTML = pairs.map(([val, label]) => `<option value="${val}">${label}</option>`).join("")
    select.disabled = !!disabled
  }

  async _fetchAndRender(url) {
    const res = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
    const html = await res.text()
    Turbo.renderStreamMessage(html) // <-- this applies the <turbo-stream> response to the DOM
  }
}
