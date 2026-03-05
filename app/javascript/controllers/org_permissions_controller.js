import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]
  static values = { url: String }

  navigate() {
    var agency = this.agencyTarget.value
    if (!agency) {
      alert("Please select at least an Agency.")
      return
    }

    var params = new URLSearchParams()
    params.set("agency_id", agency)

    var division = this.divisionTarget.value
    var department = this.departmentTarget.value
    var unit = this.unitTarget.value

    if (division) params.set("division_id", division)
    if (department) params.set("department_id", department)
    if (unit) params.set("unit_id", unit)

    window.location.href = this.urlValue + "?" + params.toString()
  }
}
