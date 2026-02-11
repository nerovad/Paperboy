import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "nameInput", "saveForm", "deleteForm"]

  load() {
    const selected = this.dropdownTarget.selectedOptions[0]
    if (!selected || !selected.value) return

    const filters = selected.dataset.filters
    if (filters) {
      const params = JSON.parse(filters)
      params.saved_search_id = selected.value
      const query = new URLSearchParams(params).toString()
      window.location.href = `${window.location.pathname}?${query}`
    }
  }

  toggleSaveForm() {
    const form = this.saveFormTarget
    const isHidden = form.style.display === "none" || form.style.display === ""
    form.style.display = isHidden ? "flex" : "none"
    if (isHidden) {
      this.nameInputTarget.focus()
    }
  }

  save(event) {
    event.preventDefault()
    const name = this.nameInputTarget.value.trim()
    if (!name) {
      this.nameInputTarget.focus()
      return
    }

    // Build a form and submit it
    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/saved_searches"

    // CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const tokenInput = document.createElement("input")
      tokenInput.type = "hidden"
      tokenInput.name = "authenticity_token"
      tokenInput.value = csrfToken
      form.appendChild(tokenInput)
    }

    // Name
    const nameInput = document.createElement("input")
    nameInput.type = "hidden"
    nameInput.name = "name"
    nameInput.value = name
    form.appendChild(nameInput)

    // Current filter params from URL
    const urlParams = new URLSearchParams(window.location.search)
    const filterKeys = [
      "filter_type", "filter_title", "filter_category", "filter_status",
      "filter_date_from", "filter_date_to", "filter_employee_name", "filter_employee_id",
      "sort_by", "sort_direction"
    ]
    filterKeys.forEach(key => {
      if (urlParams.has(key) && urlParams.get(key)) {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = key
        input.value = urlParams.get(key)
        form.appendChild(input)
      }
    })

    document.body.appendChild(form)
    form.submit()
  }

  confirmDelete() {
    const selected = this.dropdownTarget.selectedOptions[0]
    if (!selected || !selected.value) return

    const name = selected.textContent.trim()
    if (confirm(`Delete saved search "${name}"?`)) {
      this.deleteFormTarget.action = `/saved_searches/${selected.value}`
      this.deleteFormTarget.submit()
    }
  }
}
