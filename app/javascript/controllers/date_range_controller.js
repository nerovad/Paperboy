import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "progress"]

  disconnect() {
    this.stopProgress()
  }

  connect() {
    this.validateRange()
  }

  submit(event) {
    this.validateRange()
    if (this.startDateTarget.value > this.endDateTarget.value) {
      event.preventDefault()
      this.endDateTarget.reportValidity()
      return
    }

    event.preventDefault()
    this.startProgress()
    window.setTimeout(() => event.currentTarget.submit(), 0)
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
    this.stopProgress()
    requestAnimationFrame(() => this.validateRange())
  }

  startProgress() {
    if (!this.hasProgressTarget) return

    this.progressTarget.hidden = false
    this.progressStartedAt = performance.now()
    this.updateProgress()
    this.progressTimer = window.setInterval(() => this.updateProgress(), 100)
  }

  updateProgress() {
    if (!this.hasProgressTarget) return

    const elapsed = ((performance.now() - this.progressStartedAt) / 1000).toFixed(1)
    this.progressTarget.querySelector("[data-date-range-progress-label]").textContent =
      `Finding files… ${elapsed} seconds elapsed`
  }

  stopProgress() {
    if (this.progressTimer) window.clearInterval(this.progressTimer)
    this.progressTimer = null
  }
}
