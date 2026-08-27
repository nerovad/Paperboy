import { Controller } from "@hotwired/stimulus"
import { choicesOptions } from "choices_setup";

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]
  static values = {
    divisionsUrl: String, departmentsUrl: String, unitsUrl: String
  }

  connect() {
    this.choiceInstances = new Map()
    this.enhance(this.agencyTarget, "Search agencies…")
    this.enhance(this.divisionTarget, "Select an agency first", true)
    this.enhance(this.departmentTarget, "Select a division first", true)
    this.enhance(this.unitTarget, "Select a department first", true)
  }

  disconnect() {
    this.choiceInstances.forEach(choices => choices.destroy())
  }

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
      this.clearBillingString()
      return
    }

    const selects = [this.agencyTarget, this.divisionTarget, this.departmentTarget, this.unitTarget]
    const levels = ["Agency", "Division", "Department", "Unit"]
    window.dispatchEvent(new CustomEvent("coa-organization-selected", {
      detail: {
        agency: this.agencyTarget.value,
        division: this.divisionTarget.value,
        department: this.departmentTarget.value,
        unit: this.unitTarget.value,
        nodes: selects.map((select, index) => ({
          level: levels[index],
          id: select.value,
          name: this.longName(select)
        }))
      }
    }))
  }

  longName(select) {
    const label = select.selectedOptions[0].textContent
    const prefix = `${select.value} - `
    return label.startsWith(prefix) ? label.slice(prefix.length) : label
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
    this.setChoices(select, options, "Select one")
  }

  reset(...selects) {
    selects.forEach(select => {
      this.setChoices(select, [], "Select one", true)
    })
    this.clearBillingString()
  }

  setLoading(select) {
    this.setChoices(select, [], "Loading…", true)
  }

  enhance(select, placeholder, disabled = false) {
    if (!window.Choices) return

    select.disabled = false
    const choices = new window.Choices(select, choicesOptions({
      itemSelectText: "",
      placeholder: true,
      placeholderValue: placeholder,
      removeItemButton: false,
      searchEnabled: true,
      searchPlaceholderValue: "Type to search…",
      shouldSort: false
    }))
    this.choiceInstances.set(select, choices)
    if (disabled) choices.disable()
  }

  setChoices(select, options, placeholder, disabled = false) {
    const choices = this.choiceInstances.get(select)
    if (!choices) {
      select.replaceChildren(new Option(placeholder, ""), ...options.map(option => new Option(option.label, option.value)))
      select.disabled = disabled
      return
    }

    choices.clearStore()
    choices.setChoices(
      [{ value: "", label: placeholder, placeholder: true, selected: true },
       ...options],
      "value",
      "label",
      true
    )
    disabled ? choices.disable() : choices.enable()
  }

  clearBillingString() {
    window.dispatchEvent(new CustomEvent("coa-organization-cleared"))
  }
}
