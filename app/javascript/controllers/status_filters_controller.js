import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "status"]
  static values = {
    statusOptions: Object,
    allStatuses: Array
  }

  connect() {
    this.currentStatusValue = this.statusTarget.value
    this.updateStatusOptions()
  }

  typeChanged() {
    this.updateStatusOptions()
  }

  updateStatusOptions() {
    const selectedType = this.typeTarget.value
    let statuses

    if (selectedType === '') {
      // "All" selected - show all statuses from current data
      statuses = this.allStatusesValue
    } else {
      // Specific type selected - show statuses for that form type
      statuses = this.statusOptionsValue[selectedType] || this.allStatusesValue
    }

    // Rebuild the status dropdown
    const previousValue = this.statusTarget.value
    this.statusTarget.innerHTML = '<option value="">All</option>'

    statuses.forEach((status) => {
      const option = document.createElement('option')
      option.value = status
      option.textContent = status
      this.statusTarget.appendChild(option)
    })

    // Restore selection if still valid, otherwise keep "All"
    if (previousValue && statuses.includes(previousValue)) {
      this.statusTarget.value = previousValue
    } else if (this.currentStatusValue && statuses.includes(this.currentStatusValue)) {
      // On page load, restore the URL param value if valid
      this.statusTarget.value = this.currentStatusValue
    }
  }
}
