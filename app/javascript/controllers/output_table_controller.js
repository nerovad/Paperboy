import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.element.dataset.simpleSort === "true") {
      this.sortColumn(0, "descending")
      return
    }

    if (!window.jQuery || !window.jQuery.fn.DataTable || this.element.dataset.datatableInitialized === "true") return

    const table = window.jQuery(this.element).DataTable({
      dom: "Bfrtip",
      orderCellsTop: true,
      pageLength: 25,
      responsive: true,
      buttons: [
        { extend: "copyHtml5", title: this.exportTitle },
        { extend: "csvHtml5", title: this.exportTitle },
        { extend: "print", title: this.exportTitle }
      ]
    })

    table.columns().every(function () {
      const column = this
      const input = column.table().node().querySelectorAll("thead tr.column-filters input")[column.index()]
      if (!input) return

      input.addEventListener("keyup", () => {
        if (column.search() !== input.value) column.search(input.value).draw()
      })
      input.addEventListener("change", () => {
        if (column.search() !== input.value) column.search(input.value).draw()
      })
      input.addEventListener("click", event => event.stopPropagation())
    })

    this.element.dataset.datatableInitialized = "true"
  }

  changeSort(event) {
    const header = event.currentTarget.closest("th")
    const direction = header.getAttribute("aria-sort") === "ascending" ? "descending" : "ascending"
    this.sortColumn(Number(header.dataset.columnIndex), direction)
  }

  sortColumn(columnIndex, direction) {
    const headers = Array.from(this.element.querySelectorAll("thead th[data-column-index]"))
    const header = headers.find(item => Number(item.dataset.columnIndex) === columnIndex)
    const multiplier = direction === "ascending" ? 1 : -1
    const body = this.element.tBodies[0]
    const rows = Array.from(body.rows)

    rows.sort((left, right) => {
      const leftValue = left.cells[columnIndex].textContent.trim()
      const rightValue = right.cells[columnIndex].textContent.trim()
      const comparison = header.dataset.sortType === "number"
        ? Number(leftValue) - Number(rightValue)
        : leftValue.localeCompare(rightValue, undefined, { numeric: true, sensitivity: "base" })
      return multiplier * comparison
    })
    rows.forEach(row => body.appendChild(row))

    headers.forEach(item => item.setAttribute("aria-sort", "none"))
    header.setAttribute("aria-sort", direction)
  }

  get exportTitle() {
    return this.element.dataset.exportTitle || "DataRunner output"
  }
}
