import { Controller } from "@hotwired/stimulus"

// The library's selection and the bulk action bar above it.
//
// Two kinds of selection. Ticking cards selects those ids. "Select all"
// selects every asset the search matches — every page, not just this one —
// and is sent to the server as the search itself (the results page's query
// string), which Dam::AssetSelection re-runs. Ticking or unticking a card
// afterwards drops back to plain ids, since "all but these" is not something
// the server is asked to understand.
//
// Each action opens one of the bulk dialogs. The selection is written into
// every dialog's form as hidden fields as it opens, and cannot change while it
// is open because the dialog covers the grid.
export default class extends Controller {
  static targets = ["checkbox", "card", "pageToggle", "count", "allOffer", "clear",
                    "action", "modal", "form", "summary"]
  static values = { total: Number, search: String }

  connect() {
    this.all = false
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.style.overflow = ""
  }

  toggle() {
    this.all = false
    this.refresh()
  }

  togglePage() {
    const checked = this.pageToggleTarget.checked
    this.checkboxTargets.forEach((box) => { box.checked = checked })
    this.all = false
    this.refresh()
  }

  selectAll() {
    this.checkboxTargets.forEach((box) => { box.checked = true })
    this.all = true
    this.refresh()
  }

  clear() {
    this.checkboxTargets.forEach((box) => { box.checked = false })
    this.all = false
    this.refresh()
  }

  open({ params: { modal } }) {
    const dialog = this.modalTargets.find((element) => element.dataset.modal === modal)
    if (!dialog || this.count === 0) return

    this.formTargets.forEach((form) => this.stamp(form))
    dialog.hidden = false
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.closeOnEscape)
    dialog.querySelector("select, input:not([type=hidden]), textarea")?.focus()
  }

  close() {
    this.modalTargets.forEach((dialog) => { dialog.hidden = true })
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  backdropClose(event) {
    if (this.modalTargets.includes(event.target)) this.close()
  }

  get selectedIds() {
    return this.checkboxTargets.filter((box) => box.checked).map((box) => box.value)
  }

  get count() {
    return this.all ? this.totalValue : this.selectedIds.length
  }

  refresh() {
    const ids = this.selectedIds
    const onPage = this.checkboxTargets.length
    const count = this.count
    const label = `${count.toLocaleString()} ${count === 1 ? "asset" : "assets"}`

    this.countTarget.textContent = count === 0 ? "No assets selected"
      : this.all ? `All ${label} selected` : `${label} selected`
    this.summaryTargets.forEach((element) => { element.textContent = label })

    this.pageToggleTarget.checked = onPage > 0 && ids.length === onPage
    this.pageToggleTarget.indeterminate = ids.length > 0 && ids.length < onPage

    // Offered once the whole page is ticked, and only when there is more than
    // this page to have.
    this.allOfferTarget.hidden = this.all || ids.length !== onPage || this.totalValue <= onPage
    this.clearTarget.hidden = count === 0
    this.actionTargets.forEach((button) => { button.disabled = count === 0 })

    const chosen = new Set(ids)
    this.cardTargets.forEach((card) => {
      card.classList.toggle("is-selected", chosen.has(card.dataset.assetId))
    })
  }

  stamp(form) {
    form.querySelectorAll("input[data-selection-field]").forEach((input) => input.remove())

    if (this.all) {
      this.addField(form, "select_all", "1")
      this.addField(form, "search", this.searchValue)
    } else {
      this.selectedIds.forEach((id) => this.addField(form, "asset_ids[]", id))
    }
  }

  addField(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    input.dataset.selectionField = ""
    form.appendChild(input)
  }
}
