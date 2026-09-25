import { Controller } from "@hotwired/stimulus"
import { pbConfirm } from "pb_modal"

const SORT_KEYS = ["sort_by", "sort_direction"]

export default class extends Controller {
  static targets = ["dropdown", "nameInput", "saveForm", "deleteForm"]

  load() {
    const selected = this.dropdownTarget.selectedOptions[0]
    if (!selected || !selected.value) return

    const filters = selected.dataset.filters
    if (filters) {
      const query = new URLSearchParams()
      Object.entries(JSON.parse(filters)).forEach(([key, value]) => {
        if (Array.isArray(value)) {
          value.forEach(v => query.append(`${key}[]`, v))
        } else {
          query.append(key, value)
        }
      })
      query.append("saved_search_id", selected.value)
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

    // Current filter params from URL. Every filter is a `filter_` param, and
    // which ones exist depends on the user's column layout, so take them all
    // rather than a fixed list (SavedSearchesController applies the same rule).
    const urlParams = new URLSearchParams(window.location.search)
    urlParams.forEach((value, key) => {
      const bare = key.replace(/\[\]$/, "")
      if (!value || !(bare.startsWith("filter_") || SORT_KEYS.includes(bare))) return

      const input = document.createElement("input")
      input.type = "hidden"
      input.name = key
      input.value = value
      form.appendChild(input)
    })

    document.body.appendChild(form)
    form.submit()
  }

  async confirmDelete() {
    const selected = this.dropdownTarget.selectedOptions[0]
    if (!selected || !selected.value) return

    const name = selected.textContent.trim()
    const proceed = await pbConfirm({
      title: "Delete saved search",
      message: `Delete saved search "${name}"?`,
      confirmLabel: "Delete",
      confirmVariant: "deny"
    })
    if (!proceed) return

    this.deleteFormTarget.action = `/saved_searches/${selected.value}`
    this.deleteFormTarget.submit()
  }
}
