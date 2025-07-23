import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]

  connect() {
    // Trigger auto-load for prefilled values
    if (this.agencyTarget.value) this.loadDivisions()
    if (this.divisionTarget.value) this.loadDepartments()
    if (this.departmentTarget.value) this.loadUnits()
  }

  loadDivisions() {
    fetch(`/lookups/divisions?agency=${this.agencyTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }

  loadDepartments() {
    fetch(`/lookups/departments?division=${this.divisionTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }

  loadUnits() {
    fetch(`/lookups/units?department=${this.departmentTarget.value}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
  }
}
