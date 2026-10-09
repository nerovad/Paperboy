import { Controller } from "@hotwired/stimulus"

// Small client-side interactions for bounded tables. Large or protected
// datasets keep filtering and sorting in their owning server-side adapter.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll('[data-pfa-grid-target="filter"]').forEach(input => {
      input.addEventListener("input", () => this.filter())
    })
  }

  sort(event) {
    const button = event.currentTarget
    const header = button.closest("th")
    const column = Number(header.dataset.columnIndex)
    const direction = button.getAttribute("aria-sort") === "ascending" ? -1 : 1
    const type = header.dataset.sortType
    const body = this.element.tBodies[0]
    const rows = Array.from(body.rows)

    rows.sort((left, right) => {
      const a = left.cells[column].textContent.trim()
      const b = right.cells[column].textContent.trim()
      const comparison = type === "number" ? Number(a) - Number(b) :
        a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" })
      return direction * comparison
    })
    rows.forEach(row => body.appendChild(row))
    this.element.querySelectorAll("thead button[aria-sort]").forEach(item => item.setAttribute("aria-sort", "none"))
    button.setAttribute("aria-sort", direction === 1 ? "ascending" : "descending")
  }

  filter() {
    const filters = Array.from(this.element.querySelectorAll('[data-pfa-grid-target="filter"]'))
      .map(input => [Number(input.dataset.columnIndex), input.value.trim().toLocaleLowerCase()])
      .filter(([, value]) => value)

    Array.from(this.element.tBodies[0].rows).forEach(row => {
      row.hidden = !filters.every(([column, value]) =>
        row.cells[column].textContent.toLocaleLowerCase().includes(value))
    })
  }
}
