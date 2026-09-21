import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const button = event.currentTarget
    const detail = this.element.querySelector(`#${button.dataset.detailId}`)
    if (!detail) return

    const expanded = button.getAttribute("aria-expanded") === "true"
    button.setAttribute("aria-expanded", String(!expanded))
    button.querySelector("[aria-hidden='true']").textContent = expanded ? "▸" : "▾"
    button.setAttribute("aria-label", expanded ? "Show details" : "Hide details")
    detail.hidden = expanded
  }

  sort(event) {
    const button = event.currentTarget
    const table = button.closest("table")
    const header = button.closest("th")
    const column = Array.from(header.parentElement.cells).indexOf(header)
    const body = table.tBodies[0]
    const rows = Array.from(body.rows)
    const ascending = button.dataset.sortDirection !== "asc"

    rows.sort((left, right) => {
      const leftValue = this.sortValue(left.cells[column], button.dataset.sortKey)
      const rightValue = this.sortValue(right.cells[column], button.dataset.sortKey)
      return this.compare(leftValue, rightValue) * (ascending ? 1 : -1)
    })

    rows.forEach((row) => body.appendChild(row))
    button.dataset.sortDirection = ascending ? "asc" : "desc"
    button.querySelector(".customer-lookup-sort-indicator").textContent = ascending ? "▲" : "▼"
  }

  sortValue(cell, key) {
    const value = cell.dataset.sortValue || cell.textContent.trim()
    if (key === "date") return Date.parse(value)
    if (key === "amount") return Number(value.replace(/[$,]/g, ""))
    return value
  }

  compare(left, right) {
    if (typeof left === "string" || typeof right === "string") {
      return String(left).localeCompare(String(right), undefined, { numeric: true, sensitivity: "base" })
    }
    if (Number.isNaN(left) || Number.isNaN(right)) return String(left).localeCompare(String(right))
    return left - right
  }
}
