import { Controller } from "@hotwired/stimulus"

// Search a queue page as you type: person, invoice number, vendor, BU,
// submitter, total, date. Loose on purpose -- case, spaces and punctuation are
// ignored, so "op41664" finds OP-41664_FM-28844 and "house san" finds House
// Sanitary Supply, and every word typed has to match somewhere on the row.
// A group whose heading matches (a person's name) shows all its rows. Groups
// with a match open; clearing the box puts them back as they were.
export default class extends Controller {
  static targets = ["input", "row", "group", "empty"]

  connect() {
    this.groupTargets.forEach((group) => {
      const toggle = group.querySelector("[aria-expanded]")
      group.dataset.startedOpen = toggle?.getAttribute("aria-expanded") ?? "true"
    })
  }

  filter() {
    const words = this.normalize(this.inputTarget.value).split(" ").filter(Boolean)
    let shown = 0

    this.rowTargets.forEach((row) => {
      const group = row.closest("[data-aim-queue-filter-target~=group]")
      const heading = group ? this.normalize(group.dataset.search || "") : ""
      const text = `${this.normalize(row.dataset.search || "")} ${heading}`
      const match = words.every((word) => this.contains(text, word))
      row.hidden = !match
      if (match) shown += 1
    })

    this.groupTargets.forEach((group) => {
      const visible = group.querySelectorAll("[data-aim-queue-filter-target~=row]:not([hidden])").length
      group.hidden = words.length > 0 && visible === 0
      this.setOpen(group, words.length > 0 ? visible > 0 : group.dataset.startedOpen === "true")
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0 || words.length === 0
  }

  clear() {
    this.inputTarget.value = ""
    this.filter()
  }

  setOpen(group, open) {
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
