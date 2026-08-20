import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate"]

  connect() {
    this.validateRange()
  }

  validate(event) {
    this.validateRange()
    return unless this.startDateTarget.value > this.endDateTarget.value

    event.preventDefault()
    this.endDateTarget.reportValidity()
  }

  validateRange() {
    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value
    const invalid = startDate && endDate && startDate > endDate

    this.startDateTarget.max = endDate
    this.endDateTarget.min = startDate
    this.endDateTarget.setCustomValidity(invalid ? "End date must be on or after start date." : "")
  }

  reset() {
    requestAnimationFrame(() => this.validateRange())
  }
}
