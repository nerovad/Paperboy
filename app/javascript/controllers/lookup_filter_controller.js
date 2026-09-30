import { Controller } from "@hotwired/stimulus"

// Reloads a builder custom-lookup <select> when a field its options follow
// changes -- e.g. an address list narrowed by the City picked above it.
//
// The sources are field names. Each is found by swapping this select's own
// field name for the source's in its name attribute, so it works as well in a
// repeating section's row (form[rows_attributes][2][city]) as at the top level.
// Read at event time, since new rows are renumbered after connect.
//
// The server applies the same filters on first render (FormLookup.options_for
// is handed the record), so this only runs on a change. searchable-select
// notices the swapped options through its MutationObserver.
export default class extends Controller {
  static values = { form: String, field: String, sources: Array }

  connect() {
    this.onChange = event => {
      if (this.sourceNames().includes(event.target.name)) this.reload()
    }
    this.element.form?.addEventListener("change", this.onChange)
  }

  disconnect() {
    this.element.form?.removeEventListener("change", this.onChange)
  }

  sourceNames() {
    return this.sourcesValue.map(source => this.nameFor(source))
  }

  nameFor(fieldName) {
    return this.element.name.replace(new RegExp(`\\[${this.fieldValue}\\](\\[\\])?$`), `[${fieldName}]`)
  }

  async reload() {
    const params = new URLSearchParams({ form: this.formValue, field: this.fieldValue })
    this.sourcesValue.forEach(source => {
      const input = this.element.form.elements.namedItem(this.nameFor(source))
      if (input?.value) params.set(`answers[${source}]`, input.value)
    })

    let options
    try {
      const response = await fetch(`/lookups/filtered_options?${params}`, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      options = await response.json()
    } catch (e) {
      console.error("lookup-filter: reload failed", e)
      return
    }

    const previous = this.element.value
    const blank = this.element.querySelector('option[value=""]')
    this.element.replaceChildren(...(blank ? [blank] : []), ...options.map(v => new Option(v, v)))
    this.element.value = options.includes(previous) ? previous : ""

    // Dependent conditional fields (an "Other" box, say) follow the new value.
    if (this.element.value !== previous) {
      this.element.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
