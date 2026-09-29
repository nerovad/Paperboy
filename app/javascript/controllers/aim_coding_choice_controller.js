import { Controller } from "@hotwired/stimulus"
import { pbConfirm } from "pb_modal"

// Tick a coding rule and the coding fields below fill in from it at once,
// so what it would overwrite is seen before anything is saved: a field whose
// value changes is highlighted, and Undo fill puts back what was there. Save
// Changes keeps it; the hidden rule id records which rule was picked. Look
// up coding again fetches a fresh Coding box and swaps it in, no reload.
export default class extends Controller {
  static targets = ["choice", "ruleId", "note", "undo"]
  static values = { url: String }

  connect() {
    this.before = this.snapshot()
    this.choiceTargets.forEach((radio) => { if (radio.checked) this.preview(radio) })
  }

  choose(event) {
    this.preview(event.currentTarget)
  }

  undo() {
    Object.entries(this.before).forEach(([name, value]) => {
      const input = this.field(name)
      if (input) { input.value = value; input.closest(".aim-field")?.classList.remove("is-changed") }
    })
    this.choiceTargets.forEach((radio) => { radio.checked = false })
    if (this.hasRuleIdTarget) this.ruleIdTarget.value = ""
    if (this.hasNoteTarget) this.noteTarget.hidden = true
    if (this.hasUndoTarget) this.undoTarget.hidden = true
  }

  async relookup() {
    const ok = await pbConfirm({ title: "Look up coding again",
                                 message: "Run the coding rules again? The coding below is replaced by what they find.",
                                 confirmLabel: "Look up again" })
    if (!ok) return
    const token = document.querySelector("meta[name=csrf-token]")?.content
    const response = await fetch(this.urlValue, { method: "POST", headers: { "X-CSRF-Token": token, Accept: "text/html" } })
    if (!response.ok) return
    this.element.outerHTML = await response.text()
  }

  preview(radio) {
    const rule = JSON.parse(radio.dataset.rule || "{}")
    let changed = 0
    Object.entries(rule).forEach(([field, value]) => {
      const input = this.field(field)
      if (!input) return
      const original = this.before[field] ?? ""
      this.set(input, value ?? "")
      const differs = original !== input.value
      input.closest(".aim-field")?.classList.toggle("is-changed", differs && original !== "")
      if (differs) changed += 1
    })
    if (this.hasRuleIdTarget) this.ruleIdTarget.value = radio.value
    if (this.hasUndoTarget) this.undoTarget.hidden = false
    if (this.hasNoteTarget) {
      this.noteTarget.hidden = false
      this.noteTarget.textContent = changed
        ? `Filled from this rule: ${changed} field${changed === 1 ? "" : "s"} changed, highlighted where something was there before. Save Changes to keep it, or Undo fill.`
        : "This rule matches the coding already here."
    }
  }

  snapshot() {
    const values = {}
    this.element.querySelectorAll("[name^='coding_line[']").forEach((input) => {
      const name = input.name.slice("coding_line[".length, -1)
      values[name] = input.value
    })
    return values
  }

  field(name) {
    return this.element.querySelector(`[name="coding_line[${name}]"]`)
  }

  set(input, value) {
    if (input.tagName !== "SELECT") { input.value = value; return }
    const option = Array.from(input.options).find((o) => o.value === String(value))
    if (option) { input.value = option.value; return }
    if (value === "") { input.value = ""; return }
    input.add(new Option(`${value} · (not in the list)`, value, true, true))
  }
}
