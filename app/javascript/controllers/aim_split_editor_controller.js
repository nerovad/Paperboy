import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

// The split screen (#192): the PDF editor's "New invoice starts here" marks
// fill each invoice's pages here, as they are set (aim-split:pages, sent by
// aim_pdf_editor_controller). Vendors and numbers typed in are kept; a row is
// added when there are more invoices than rows. While the editor holds
// changes not yet applied the pages are numbered as they will be after
// Apply, so Approve Split waits for Apply.
export default class extends Controller {
  static targets = ["rows", "pages", "pending", "seen"]

  connect() {
    this.pending = false
    this.onPages = (event) => this.fill(event.detail)
    window.addEventListener("aim-split:pages", this.onPages)
    this.form = this.element.closest("form")
    this.onSubmit = (event) => this.guard(event)
    this.form?.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    window.removeEventListener("aim-split:pages", this.onPages)
    this.form?.removeEventListener("submit", this.onSubmit)
  }

  // detail: { ranges: [[first, last], ...] or null, pending: Boolean }
  fill({ ranges, pending }) {
    this.pending = Boolean(pending)
    this.pendingTarget.hidden = !this.pending
    if (!ranges) return
    while (this.pagesTargets.length < ranges.length) this.addRow()
    this.pagesTargets.forEach((input, index) => {
      const range = ranges[index]
      input.value = range ? (range[0] === range[1] ? `${range[0]}` : `${range[0]}-${range[1]}`) : ""
    })
  }

  // A copy of the last row, numbered on, empty: + Add an invoice, or a mark
  // made in Edit PDF past the last row.
  addRow(event) {
    const last = this.rowsTarget.lastElementChild
    const row = last.cloneNode(true)
    const index = this.rowsTarget.children.length
    row.querySelector("td").textContent = `${index + 1}`
    // A new invoice has no AI guess to show or keep.
    row.querySelectorAll(".aim-split-seen, input[type=hidden]").forEach((element) => element.remove())
    row.querySelectorAll("input").forEach((input) => {
      input.name = input.name.replace(/split\[\d+\]/, `split[${index}]`)
      input.id = input.name.replace(/\]\[|\[|\]/g, "_").replace(/_$/, "")
      input.setAttribute("aria-label", input.getAttribute("aria-label").replace(/Invoice \d+/, `Invoice ${index + 1}`))
      input.value = ""
    })
    this.rowsTarget.appendChild(row)
    if (event) row.querySelector("input")?.focus()
    return row
  }

  guard(event) {
    if (!this.pending || event.submitter?.value !== "approve_split") return
    event.preventDefault()
    event.stopImmediatePropagation()
    pbAlert({ title: "Apply the PDF changes first",
              message: "Edit PDF has changes not yet applied, and the split cuts the PDF as applied. Press Apply changes, then approve the split." })
  }
}
