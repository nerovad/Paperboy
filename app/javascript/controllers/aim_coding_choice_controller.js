import { Controller } from "@hotwired/stimulus"

// Tick a coding rule and the coding fields below fill in from it at once,
// so what it would overwrite is seen before anything is saved: a field whose
// value changes is highlighted. Save Changes keeps it; the hidden rule id
// records which rule was picked.
export default class extends Controller {
  static targets = ["choice", "ruleId", "note"]

  connect() {
    this.choiceTargets.forEach((radio) => { if (radio.checked) this.preview(radio) })
  }

  choose(event) {
    this.preview(event.currentTarget)
  }

  preview(radio) {
    const rule = JSON.parse(radio.dataset.rule || "{}")
    let changed = 0
    Object.entries(rule).forEach(([field, value]) => {
      const input = this.element.querySelector(`[name="coding_line[${field}]"]`)
      if (!input) return
      const before = input.value
      this.set(input, value ?? "")
      const differs = before !== input.value
      input.closest(".aim-field")?.classList.toggle("is-changed", differs && before !== "")
      if (differs) changed += 1
    })
    if (this.hasRuleIdTarget) this.ruleIdTarget.value = radio.value
    if (this.hasNoteTarget) {
      this.noteTarget.hidden = false
      this.noteTarget.textContent = changed
        ? `Filled from this rule: ${changed} field${changed === 1 ? "" : "s"} changed, highlighted where something was there before. Save Changes to keep it.`
        : "This rule matches the coding already here."
    }
  }

  set(input, value) {
    if (input.tagName !== "SELECT") { input.value = value; return }
    const option = Array.from(input.options).find((o) => o.value === String(value))
    if (option) { input.value = option.value; return }
    if (value === "") { input.value = ""; return }
    const added = new Option(`${value} · (not in the list)`, value, true, true)
    input.add(added)
  }
}
