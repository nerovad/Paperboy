import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "status", "title"]
  static values = {
    statusOptions: Object,
    allStatuses: Array,
    titleOptions: Object,
    allTitles: Array
  }

  connect() {
    this.currentStatusValue = this.statusTarget.value
    this.currentTitleValue = this.titleTarget.value
    this.updateStatusOptions()
    this.updateTitleOptions()
  }

  typeChanged() {
    this.updateStatusOptions()
    this.updateTitleOptions()
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

  updateTitleOptions() {
    const selectedType = this.typeTarget.value
    let titles

    if (selectedType === '') {
      // "All" selected - show all titles from current data
      titles = this.allTitlesValue
    } else {
      // Specific type selected - show titles for that form type
      titles = this.titleOptionsValue[selectedType] || this.allTitlesValue
    }

    // Rebuild the title dropdown
    const previousValue = this.titleTarget.value
    this.titleTarget.innerHTML = '<option value="">All</option>'

    titles.forEach((title) => {
      const option = document.createElement('option')
      option.value = title
      option.textContent = title
      this.titleTarget.appendChild(option)
    })

    // Restore selection if still valid, otherwise keep "All"
    if (previousValue && titles.includes(previousValue)) {
      this.titleTarget.value = previousValue
    } else if (this.currentTitleValue && titles.includes(this.currentTitleValue)) {
      // On page load, restore the URL param value if valid
      this.titleTarget.value = this.currentTitleValue
    }
  }}
