// app/javascript/controllers/scheduled_report_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "scheduleCheckbox",
    "oneTimeFields",
    "scheduledFields",
    "frequencySelect",
    "weeklyField",
    "monthlyField",
    "submitButton",
    "startDate",
    "endDate",
    "dateRangeType",
    "timeOfDay",
    "dayOfWeek",
    "dayOfMonth"
  ]

  connect() {
    // Initialize field visibility on page load
    this.toggleScheduleFields()
    this.toggleFrequencyFields()
  }

  toggleScheduleFields() {
    const isScheduled = this.scheduleCheckboxTarget.checked

    if (isScheduled) {
      // Show scheduled fields, hide one-time fields
      this.oneTimeFieldsTarget.style.display = "none"
      this.scheduledFieldsTarget.style.display = "block"

      // Make scheduled fields required
      if (this.hasDateRangeTypeTarget) this.dateRangeTypeTarget.required = true
      if (this.hasFrequencySelectTarget) this.frequencySelectTarget.required = true
      if (this.hasTimeOfDayTarget) this.timeOfDayTarget.required = true

      // Make one-time fields not required
      if (this.hasStartDateTarget) this.startDateTarget.required = false
      if (this.hasEndDateTarget) this.endDateTarget.required = false

      // Update button text
      this.submitButtonTarget.value = "Create Schedule"
    } else {
      // Show one-time fields, hide scheduled fields
      this.oneTimeFieldsTarget.style.display = "block"
      this.scheduledFieldsTarget.style.display = "none"

      // Make one-time fields required
      if (this.hasStartDateTarget) this.startDateTarget.required = true
      if (this.hasEndDateTarget) this.endDateTarget.required = true

      // Make scheduled fields not required
      if (this.hasDateRangeTypeTarget) this.dateRangeTypeTarget.required = false
      if (this.hasFrequencySelectTarget) this.frequencySelectTarget.required = false
      if (this.hasTimeOfDayTarget) this.timeOfDayTarget.required = false

      // Update button text
      this.submitButtonTarget.value = "Generate Report"
    }
  }

  toggleFrequencyFields() {
    if (!this.hasFrequencySelectTarget) return

    const frequency = this.frequencySelectTarget.value

    // Hide all frequency-specific fields
    this.weeklyFieldTarget.style.display = "none"
    this.monthlyFieldTarget.style.display = "none"

    // Clear required attribute from both
    if (this.hasDayOfWeekTarget) this.dayOfWeekTarget.required = false
    if (this.hasDayOfMonthTarget) this.dayOfMonthTarget.required = false

    // Show relevant field based on frequency
    if (frequency === "weekly") {
      this.weeklyFieldTarget.style.display = "block"
      if (this.hasDayOfWeekTarget) this.dayOfWeekTarget.required = true
    } else if (frequency === "monthly") {
      this.monthlyFieldTarget.style.display = "block"
      if (this.hasDayOfMonthTarget) this.dayOfMonthTarget.required = true
    }
  }
}
