import { Controller } from "@hotwired/stimulus"
import { choicesOptions } from "choices_setup";

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit", "accountFields", "result",
                    "cobject", "cactivity", "cfunction", "cprogram", "cphase", "ctask",
                    "agencyId", "divisionId", "departmentId", "unitId",
                    "agencyName", "divisionName", "departmentName", "unitName",
                    "billingAgencyId", "billingDivisionId", "billingDepartmentId", "billingUnitId"]
  static values = {
    divisionsUrl: String, departmentsUrl: String, unitsUrl: String,
    objectsUrl: String, activitiesUrl: String, cfunctionsUrl: String,
    programsUrl: String, phasesUrl: String, tasksUrl: String
  }

  connect() {
    this.choiceInstances = new Map()
    this.enhance(this.agencyTarget, "Search agencies…")
    this.enhance(this.divisionTarget, "Select an agency first", true)
    this.enhance(this.departmentTarget, "Select a division first", true)
    this.enhance(this.unitTarget, "Select a department first", true)
    this.accountSelects().forEach(select => this.enhance(select, "Select an agency first", true))
  }

  disconnect() {
    this.choiceInstances.forEach(choices => choices.destroy())
  }

  agencyChanged() {
    this.reset(this.divisionTarget, this.departmentTarget, this.unitTarget)
    this.reset(...this.accountSelects())
    if (!this.agencyTarget.value) return

    this.load(this.divisionTarget, this.divisionsUrlValue, { agency_id: this.agencyTarget.value })
    this.loadAccountFields()
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
      this.accountFieldsTarget.hidden = true
      this.resultTarget.hidden = true
      return
    }

    const selects = [this.agencyTarget, this.divisionTarget, this.departmentTarget, this.unitTarget]
    const idTargets = [this.agencyIdTarget, this.divisionIdTarget,
                       this.departmentIdTarget, this.unitIdTarget]
    const billingIdTargets = [this.billingAgencyIdTarget, this.billingDivisionIdTarget,
                              this.billingDepartmentIdTarget, this.billingUnitIdTarget]
    const nameTargets = [this.agencyNameTarget, this.divisionNameTarget,
                         this.departmentNameTarget, this.unitNameTarget]
    selects.forEach((select, index) => {
      idTargets[index].textContent = select.value
      billingIdTargets[index].textContent = select.value
      nameTargets[index].textContent = this.longName(select)
    })
    this.accountFieldsTarget.hidden = false
    this.resultTarget.hidden = false
  }

  async copy() {
    const accountString = [this.agencyTarget, this.divisionTarget, this.departmentTarget,
                           this.unitTarget, ...this.accountSelects()].map(select => select.value).join("")
    await navigator.clipboard.writeText(accountString)
  }

  loadAccountFields() {
    const agencyParams = { agency_id: this.agencyTarget.value }
    this.load(this.cobjectTarget, this.objectsUrlValue, agencyParams)
    this.load(this.cactivityTarget, this.activitiesUrlValue, agencyParams)
    this.load(this.cfunctionTarget, this.cfunctionsUrlValue, agencyParams)
    this.load(this.cprogramTarget, this.programsUrlValue, agencyParams)
    this.load(this.cphaseTarget, this.phasesUrlValue, agencyParams)
    this.load(this.ctaskTarget, this.tasksUrlValue, agencyParams)
  }

  accountSelects() {
    return [this.cobjectTarget, this.cactivityTarget, this.cfunctionTarget,
            this.cprogramTarget, this.cphaseTarget, this.ctaskTarget]
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
    this.accountFieldsTarget.hidden = true
    this.resultTarget.hidden = true
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
    const renderedOptions = this.accountSelects().includes(select) ? options.map(option => ({
      ...option,
      customProperties: { selectedLabel: option.value }
    })) : options
    choices.setChoices(
      [{ value: "", label: placeholder, placeholder: true, selected: true },
       ...renderedOptions],
      "value",
      "label",
      true
    )
    disabled ? choices.disable() : choices.enable()
  }
}
