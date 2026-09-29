import { Controller } from "@hotwired/stimulus"

// Search a queue page as you type: person, invoice number, vendor, BU,
// submitter, total, date. Loose on purpose -- case, spaces and punctuation are
// ignored, so "op41664" finds OP-41664_FM-28844 and "house san" finds House
// Sanitary Supply, and every word typed has to match somewhere on the row.
// A group whose heading matches (a person's name) shows all its rows. Groups
// with a match open; clearing the box puts them back as they were.
export default class extends Controller {
  static targets = ["input", "row", "group", "empty", "reason"]
  static values = { reason: String }

  connect() {
    this.groupTargets.forEach((group) => {
      const toggle = group.querySelector("[aria-expanded]")
      const open = group.tagName === "DETAILS" ? String(group.open) : toggle?.getAttribute("aria-expanded")
      group.dataset.startedOpen = open ?? "true"
    })
  }

  // The reason buttons on Action Needed narrow the rows in place, no reload.
  pickReason(event) {
    this.reasonValue = event.currentTarget.dataset.reason || ""
    this.reasonTargets.forEach((button) => {
      const active = (button.dataset.reason || "") === this.reasonValue
      button.classList.toggle("active", active)
      button.classList.toggle("ghost", !active)
    })
    this.filter()
  }

  filter() {
    const words = this.normalize(this.inputTarget.value).split(" ").filter(Boolean)
    const reason = this.reasonValue || ""
    let shown = 0

    this.rowTargets.forEach((row) => {
      const group = row.closest("[data-aim-queue-filter-target~=group]")
      const heading = group ? this.normalize(group.dataset.search || "") : ""
      const text = `${this.normalize(row.dataset.search || "")} ${heading}`
      const match = words.every((word) => this.contains(text, word)) && (!reason || (row.dataset.reason || "") === reason)
      row.hidden = !match
      if (match) shown += 1
    })

    this.groupTargets.forEach((group) => {
      const visible = group.querySelectorAll("[data-aim-queue-filter-target~=row]:not([hidden])").length
      const filtering = words.length > 0 || reason !== ""
      group.hidden = filtering && visible === 0
      this.setOpen(group, filtering ? visible > 0 : group.dataset.startedOpen === "true")
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0 || (words.length === 0 && reason === "")
  }

  clear() {
    this.inputTarget.value = ""
    this.filter()
  }

  // A group is a collapsible section with a toggle, or a native <details>.
  setOpen(group, open) {
    if (group.tagName === "DETAILS") {
      group.open = open
      return
    }
    const toggle = group.querySelector("[aria-expanded]")
    const content = group.querySelector("[data-billing-audit-sections-target=content]")
    if (!toggle || !content) return
    toggle.setAttribute("aria-expanded", String(open))
    content.hidden = !open
  }

  // Lowercase, punctuation to spaces, runs of space collapsed.
  normalize(text) {
    return text.toLowerCase().replace(/[^a-z0-9$.]+/g, " ").replace(/\s+/g, " ").trim()
  }

  // A word matches if it appears as typed, or with the row's spaces removed
  // (so OP-41664 matches "op41664").
  contains(text, word) {
    return text.includes(word) || text.replace(/ /g, "").includes(word)
  }
}
