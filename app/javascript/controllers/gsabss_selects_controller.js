import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]

  connect() {
    // Don’t clear anything on connect — keep prefilled values
  }

  loadDivisions() {
    this.clear(this.divisionTarget)
    this.clear(this.departmentTarget)
    this.clear(this.unitTarget)

    fetch(`/lookups/divisions?agency=${this.agencyTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }

  loadDepartments() {
    this.clear(this.departmentTarget)
    this.clear(this.unitTarget)

    fetch(`/lookups/departments?division=${this.divisionTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }

  loadUnits() {
    this.clear(this.unitTarget)

    fetch(`/lookups/units?department=${this.departmentTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }

  clear(select) {
    if (!select) return

    // Save the select's id and data attributes
    const id = select.id
    const target = select.getAttribute("data-gsabss-selects-target")
    const action = select.getAttribute("data-action")

    // Replace the select's contents with a single blank option
    select.innerHTML = ''
    const blankOption = document.createElement("option")
    blankOption.value = ""
    blankOption.textContent = "Select one"
    select.appendChild(blankOption)

    // Re-apply id and data attributes so Turbo can re-target correctly
    select.id = id
    if (target) select.setAttribute("data-gsabss-selects-target", target)
    if (action) select.setAttribute("data-action", action)
  }
}
