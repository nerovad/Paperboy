import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit", "result", "accountString", "summary"]
  static values = { divisionsUrl: String, departmentsUrl: String, unitsUrl: String }

  agencyChanged() {
    this.reset(this.divisionTarget, this.departmentTarget, this.unitTarget)
    if (!this.agencyTarget.value) return

    this.load(this.divisionTarget, this.divisionsUrlValue, { agency_id: this.agencyTarget.value })
  }

  divisionChanged() {
    this.reset(this.departmentTarget, this.unitTarget)
    if (!this.divisionTarget.value) return

    this.load(this.departmentTarget, this.departmentsUrlValue, {
      agency_id: this.agencyTarget.value,
      division_id: this.divisionTarget.value
    })
  }

  departmentChanged() {
    this.reset(this.unitTarget)
    if (!this.departmentTarget.value) return

    this.load(this.unitTarget, this.unitsUrlValue, {
      agency_id: this.agencyTarget.value,
      division_id: this.divisionTarget.value,
      department_id: this.departmentTarget.value
    })
  }

  unitChanged() {
    if (!this.unitTarget.value) {
      this.resultTarget.hidden = true
      return
    }

    const selects = [this.agencyTarget, this.divisionTarget, this.departmentTarget, this.unitTarget]
    this.accountStringTarget.textContent = selects.map(select => select.value).join("")
    this.summaryTarget.textContent = selects.map(select => select.selectedOptions[0].textContent).join(" → ")
    this.resultTarget.hidden = false
  }

  async copy() {
    await navigator.clipboard.writeText(this.accountStringTarget.textContent)
  }

  async load(select, url, params) {
    this.setLoading(select)
    const query = new URLSearchParams(params)
    const response = await fetch(`${url}?${query}`, { headers: { Accept: "application/json" } })
    if (!response.ok) {
      this.reset(select)
      return
    }

    const options = await response.json()
    select.innerHTML = this.optionMarkup(options)
    select.disabled = false
  }

  reset(...selects) {
    selects.forEach(select => {
      select.innerHTML = '<option value="">Select one</option>'
      select.disabled = true
    })
    this.resultTarget.hidden = true
  }

  setLoading(select) {
    select.innerHTML = '<option value="">Loading…</option>'
    select.disabled = true
  }

  optionMarkup(options) {
    const prompt = '<option value="">Select one</option>'
    return prompt + options.map(option => (
      `<option value="${this.escape(option.value)}">${this.escape(option.label)}</option>`
    )).join("")
  }

  escape(value) {
    const element = document.createElement("span")
    element.textContent = value
    return element.innerHTML
  }
}
