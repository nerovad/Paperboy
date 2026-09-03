import { Controller } from "@hotwired/stimulus"
import { choicesOptions } from "choices_setup"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit",
                    "cobject", "cactivity", "cfunction", "cprogram", "cphase", "ctask"]
  static values = {
    objectsUrl: String, activitiesUrl: String, cfunctionsUrl: String,
    programsUrl: String, phasesUrl: String, tasksUrl: String
  }

  connect() {
    this.choiceInstances = new Map()
    this.accountSelects().forEach(select => this.enhance(select))
  }

  disconnect() {
    this.choiceInstances.forEach(choices => choices.destroy())
  }

  organizationSelected({ detail }) {
    this.agencyTarget.textContent = detail.agency
    this.divisionTarget.textContent = detail.division
    this.departmentTarget.textContent = detail.department
    this.unitTarget.textContent = detail.unit
    this.resetSelects()
    this.loadAccountFields(detail.agency)
    this.element.hidden = false
  }

  clear() {
    this.element.hidden = true
    this.resetSelects()
  }

  async copy() {
    const organization = [this.agencyTarget, this.divisionTarget,
                          this.departmentTarget, this.unitTarget]
    const accountString = [...organization, ...this.accountSelects()]
      .map(element => element.value || element.textContent)
      .join("")
    await navigator.clipboard.writeText(accountString)
  }

  loadAccountFields(agency) {
    const params = { agency_id: agency }
    this.load(this.cobjectTarget, this.objectsUrlValue, params)
    this.load(this.cactivityTarget, this.activitiesUrlValue, params)
    this.load(this.cfunctionTarget, this.cfunctionsUrlValue, params)
    this.load(this.cprogramTarget, this.programsUrlValue, params)
    this.load(this.cphaseTarget, this.phasesUrlValue, params)
    this.load(this.ctaskTarget, this.tasksUrlValue, params)
  }

  accountSelects() {
    return [this.cobjectTarget, this.cactivityTarget, this.cfunctionTarget,
            this.cprogramTarget, this.cphaseTarget, this.ctaskTarget]
  }

  async load(select, url, params) {
    this.setChoices(select, [], "Loading…", true)
    const query = new URLSearchParams(params)
    const response = await fetch(`${url}?${query}`, { headers: { Accept: "application/json" } })
    if (!response.ok) {
      this.setChoices(select, [], "Select one", true)
      return
    }

    this.setChoices(select, await response.json(), "Select one")
  }

  resetSelects() {
    this.accountSelects().forEach(select => this.setChoices(select, [], "Select one", true))
  }

  enhance(select) {
    if (!window.Choices) return

    select.disabled = false
    const choices = new window.Choices(select, choicesOptions({
      itemSelectText: "",
      placeholder: true,
      placeholderValue: "Select an agency first",
      removeItemButton: false,
      searchEnabled: true,
      searchPlaceholderValue: "Type to search…",
      shouldSort: false
    }))
    this.choiceInstances.set(select, choices)
    choices.disable()
  }

  setChoices(select, options, placeholder, disabled = false) {
    const choices = this.choiceInstances.get(select)
    if (!choices) {
      select.replaceChildren(new Option(placeholder, ""),
                             ...options.map(option => new Option(option.label, option.value)))
      select.disabled = disabled
      return
    }

    const renderedOptions = options.map(option => ({
      ...option,
      customProperties: { selectedLabel: option.value }
    }))
    choices.clearStore()
    choices.setChoices(
      [{ value: "", label: placeholder, placeholder: true, selected: true }, ...renderedOptions],
      "value",
      "label",
      true
    )
    disabled ? choices.disable() : choices.enable()
  }
}
