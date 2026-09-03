import { Controller } from "@hotwired/stimulus"
import { choicesOptions } from "choices_setup";

export default class extends Controller {
  static targets = ["agency", "object", "activity", "function", "program", "phase", "task"]
  static values = { url: String }

  connect() {
    this.choiceInstances = new Map()
    this.fieldTargets().forEach(([_name, select]) => this.enhance(select))
    this.load()
  }

  disconnect() {
    this.abortController?.abort()
    this.choiceInstances.forEach(choices => choices.destroy())
  }

  async load(event) {
    if (event) this.fieldTargets().forEach(([_name, select]) => { select.dataset.selectedValue = "" })

    this.abortController?.abort()
    this.abortController = new AbortController()
    const query = new URLSearchParams({ agency_id: this.agencyTarget.value })
    try {
      const response = await fetch(`${this.urlValue}?${query}`, {
        headers: { Accept: "application/json" }, signal: this.abortController.signal
      })
      if (!response.ok) throw new Error(`Accounting fields request failed: ${response.status}`)

      const fields = await response.json()
      this.fieldTargets().forEach(([name, select]) => this.replaceOptions(select, fields[name]))
    } catch (error) {
      if (error.name === "AbortError") return

      this.fieldTargets().forEach(([_name, select]) => this.disable(select))
    }
  }

  fieldTargets() {
    return [
      ["object", this.objectTarget], ["activity", this.activityTarget],
      ["function", this.functionTarget], ["program", this.programTarget],
      ["phase", this.phaseTarget], ["task", this.taskTarget]
    ]
  }

  replaceOptions(select, options) {
    const selected = select.dataset.selectedValue
    const choices = this.choiceInstances.get(select)
    if (choices) {
      choices.clearStore()
      choices.setChoices(
        [{ value: "", label: "Select...", placeholder: true }, ...options.map(option => ({
          value: String(option.value), label: option.label, selected: String(option.value) === selected
        }))],
        "value",
        "label",
        true
      )
      choices.enable()
      return
    }

    select.replaceChildren(new Option("Select...", ""), ...options.map(option => {
      return new Option(option.label, option.value, false, String(option.value) === selected)
    }))
    select.disabled = false
  }

  enhance(select) {
    if (!window.Choices) return

    select.disabled = false
    const choices = new window.Choices(select, choicesOptions({
      itemSelectText: "",
      placeholder: true,
      placeholderValue: "Select...",
      removeItemButton: false,
      searchEnabled: true,
      searchPlaceholderValue: "Type to search…",
      shouldSort: false
    }))
    choices.disable()
    this.choiceInstances.set(select, choices)
  }

  disable(select) {
    const choices = this.choiceInstances.get(select)
    choices ? choices.disable() : select.disabled = true
  }
}
