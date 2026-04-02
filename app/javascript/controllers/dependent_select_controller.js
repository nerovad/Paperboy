// app/javascript/controllers/dependent_select_controller.js
//
// Generic controller that populates a <select> based on another select's value.
// Fetches JSON from a URL with the source value as a query param.
//
// Usage:
//   <div data-controller="dependent-select"
//        data-dependent-select-url-value="/lookups/employees"
//        data-dependent-select-param-value="agency"
//        data-dependent-select-column-value="full_name"
//        data-dependent-select-source-selector-value="#agency-select">
//     <select data-dependent-select-target="select">...</select>
//   </div>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  static values = {
    url: String,            // e.g. "/lookups/employees"
    param: String,          // query param name for the source value, e.g. "agency"
    column: String,         // column param to pass, e.g. "full_name"
    sourceSelector: String  // CSS selector for the source <select>, e.g. "#agency-select"
  }

  connect() {
    this.sourceElement = document.querySelector(this.sourceSelectorValue)
    if (this.sourceElement) {
      this._boundLoad = this.load.bind(this)
      this.sourceElement.addEventListener("change", this._boundLoad)
      // Load initial options if source already has a value
      if (this.sourceElement.value) {
        this.load()
      }
    }
  }

  disconnect() {
    if (this.sourceElement && this._boundLoad) {
      this.sourceElement.removeEventListener("change", this._boundLoad)
    }
  }

  async load() {
    const sourceValue = this.sourceElement.value
    const select = this.selectTarget

    if (!sourceValue) {
      select.innerHTML = '<option value="">Select...</option>'
      return
    }

    select.innerHTML = '<option value="">Loading...</option>'
    select.disabled = true

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set(this.paramValue, sourceValue)
      if (this.hasColumnValue) {
        url.searchParams.set("column", this.columnValue)
      }

      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const options = await response.json()

      select.innerHTML = '<option value="">Select...</option>'
      options.forEach(value => {
        const option = document.createElement("option")
        option.value = value
        option.textContent = value
        select.appendChild(option)
      })
    } catch (error) {
      console.error("[DependentSelect] fetch error:", error)
      select.innerHTML = '<option value="">Error loading options</option>'
    } finally {
      select.disabled = false
    }
  }
}
