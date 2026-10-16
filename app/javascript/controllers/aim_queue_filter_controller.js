import { Controller } from "@hotwired/stimulus"

// Search a queue page as you type: person, invoice number, vendor, BU,
// submitter, total, date. Loose on purpose -- case, spaces and punctuation are
// ignored, so "op41664" finds OP-41664_FM-28844 and "house san" finds House
// Sanitary Supply, and every word typed has to match somewhere on the row.
// A group whose heading matches (a person's name) shows all its rows. Groups
// with a match open; clearing the box puts them back as they were.
//
// Paging (#101): with page-size set, the rows that match are shown a page at a
// time, and the pager target gets the centered series (< 1 2 3 >) and
// "Showing x-y of N rows", as Records and DataRunner have them -- always, even
// on one page, so the Rows choice visibly does something. Search,
// reasons and facets apply to every row first, then the page is cut; a row
// that matches carries data-match="1" whichever page it is on, so Select all
// (selectMatching, aim-move-modal) takes every match, not only this page.
export default class extends Controller {
  static targets = ["input", "row", "group", "empty", "reason", "facet", "count", "pager", "scroll", "size"]
  static values = { reason: String, pageSize: { type: Number, default: 0 }, page: { type: Number, default: 1 } }

  connect() {
    this.groupTargets.forEach((group) => {
      const toggle = group.querySelector("[aria-expanded]")
      const open = group.tagName === "DETAILS" ? String(group.open) : toggle?.getAttribute("aria-expanded")
      group.dataset.startedOpen = open ?? "true"
    })
    // A link may name a reason to start on (?reason=duplicate, from the dashboard).
    this.restoreSize()
    const start = this.reasonTargets.find((button) => this.reasonValue && button.dataset.reason === this.reasonValue)
    if (start) start.click()
    else if (this.hasPagerTarget) this.apply()
  }

  // Rows under a list: how many a page shows, 0 for All. Kept in this
  // browser for every AIM list (best effort; private windows may refuse).
  resize(event) {
    const size = Number(event.currentTarget.value)
    try { window.localStorage.setItem("aim-list-page-size", String(size)) } catch (_) { /* not kept */ }
    this.pageSizeValue = size
  }

  restoreSize() {
    if (!this.hasSizeTarget) return
    let saved = null
    try { saved = window.localStorage.getItem("aim-list-page-size") } catch (_) { /* nothing kept */ }
    const offered = [...this.sizeTarget.options].map((option) => option.value)
    if (saved !== null && offered.includes(saved)) {
      this.sizeTarget.value = saved
      this.pageSizeValue = Number(saved)
    }
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

  // A different page size (set on the element) pages again from page 1.
  pageSizeValueChanged(size, previous) {
    if (previous === undefined) return
    this.pageValue = 1
    this.apply()
  }

  // A new search or filter starts again on page 1.
  filter() {
    this.pageValue = 1
    this.apply()
  }

  // The pager's links.
  goTo(event) {
    event.preventDefault()
    const page = Number(event.currentTarget.dataset.page)
    if (!page) return
    this.pageValue = page
    this.apply()
    if (this.hasScrollTarget) this.scrollTarget.scrollTop = 0
  }

  // Ticks (or unticks) the checkbox on every row that matches, on every page.
  selectMatching(event) {
    const on = event.currentTarget.checked
    this.rowTargets.forEach((row) => {
      if (row.dataset.match === "0") return
      row.querySelectorAll("input[type=checkbox][name]").forEach((box) => { box.checked = on })
    })
  }

  apply() {
    const words = this.hasInputTarget ? this.normalize(this.inputTarget.value).split(" ").filter(Boolean) : []
    const reason = this.reasonValue || ""
    const matching = []

    this.rowTargets.forEach((row) => {
      const group = row.closest("[data-aim-queue-filter-target~=group]")
      const heading = group ? this.normalize(group.dataset.search || "") : ""
      const text = `${this.normalize(row.dataset.search || "")} ${heading}`
      const match = words.every((word) => this.contains(text, word)) && (!reason || (row.dataset.reason || "") === reason) &&
                    this.facetTargets.every((facet) => !facet.value || (row.dataset[facet.dataset.key] || "") === facet.value)
      row.dataset.match = match ? "1" : "0"
      if (match) matching.push(row)
    })
    const shown = matching.length

    const size = this.pageSizeValue
    const pages = size > 0 ? Math.max(1, Math.ceil(shown / size)) : 1
    if (this.pageValue > pages) this.pageValue = pages
    const first = size > 0 ? (this.pageValue - 1) * size : 0
    const onPage = new Set(size > 0 ? matching.slice(first, first + size) : matching)
    this.rowTargets.forEach((row) => { row.hidden = !onPage.has(row) })
    this.renderPager(shown, pages, first, onPage.size)

    const filtering = words.length > 0 || reason !== "" || this.facetTargets.some((facet) => facet.value)
    this.groupTargets.forEach((group) => {
      const visible = group.querySelectorAll("[data-aim-queue-filter-target~=row]:not([hidden])").length
      group.hidden = (filtering || pages > 1) && visible === 0
      this.setOpen(group, filtering ? visible > 0 : group.dataset.startedOpen === "true")
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0 || (words.length === 0 && reason === "" && !this.facetTargets.some((f) => f.value))
    if (this.hasCountTarget) this.countTarget.textContent = `${shown} ${shown === 1 ? this.countTarget.dataset.one : this.countTarget.dataset.many}`
  }

  // The centered series and the range, in the markup Records' pager uses
  // (shared/_series_pagination), so it looks the same.
  renderPager(total, pages, first, count) {
    if (!this.hasPagerTarget) return
    const current = this.pageValue
    const link = (label, page, attributes = "") =>
      `<a href="#" data-action="aim-queue-filter#goTo" data-page="${page || ""}" ${attributes}>${label}</a>`
    const items = [current > 1 ? link("&lt;", current - 1, 'aria-label="Previous"') : '<a aria-disabled="true" aria-label="Previous">&lt;</a>']
    let last = 0
    for (let page = 1; page <= pages; page += 1) {
      if (page !== 1 && page !== pages && Math.abs(page - current) > 2) continue
      if (last && page - last > 1) items.push('<a role="separator" aria-disabled="true">&hellip;</a>')
      items.push(page === current ? `<a aria-current="page" aria-disabled="true">${page}</a>` : link(page, page))
      last = page
    }
    items.push(current < pages ? link("&gt;", current + 1, 'aria-label="Next"') : '<a aria-disabled="true" aria-label="Next">&gt;</a>')
    this.pagerTarget.innerHTML =
      `<div class="pagination-wrapper"><nav class="pagy series-nav" aria-label="Pages">${items.join("")}</nav>` +
      `<p class="pagination-info">Page ${current} of ${pages} &middot; ${total ? `Showing ${first + 1}&ndash;${first + count} of ${total} rows` : "No rows match"}</p></div>`
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
