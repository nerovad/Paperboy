// app/javascript/controllers/advanced_search_controller.js
//
// The Advanced Search panel in the Paperboy sidebar.
//
// Two jobs: open and close the dialog, and keep the org selects consistent —
// Agency → Division → Department → Unit, where each list depends on the one
// above it and only the server knows the codes. Lists come from /lookups as
// JSON rather than the turbo_stream responses gsabss_selects_controller.js
// uses, because that controller replaces fixed DOM ids and this panel is on
// every page — including form pages that already own those ids.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "agency", "division", "department", "unit",
    "divisionLabel", "departmentLabel",
  ]

  // { swappedAgencyIds: [...], canonical: {...}, swapped: {...} } — rendered
  // from OrgLabels so the Ruby and JS vocabularies can't drift.
  static values = { orgLabels: Object }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.applyOrgLabels()
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.style.overflow = ""
  }

  open() {
    this.modalTarget.hidden = false
    document.body.style.overflow = "hidden"
    // Escape is bound on the document rather than the dialog so it works
    // before anything inside has been focused.
    document.addEventListener("keydown", this.closeOnEscape)
    this.modalTarget.querySelector("input, select")?.focus()
  }

  close() {
    this.modalTarget.hidden = true
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  // Only a click on the backdrop itself dismisses; clicks that bubble up from
  // the panel are the user working inside the form.
  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }

  // ===== org cascade =====
  // Each level clears everything below it: a division that belonged to the old
  // agency is not a narrower version of the new one, it is simply wrong.
  async loadDivisions() {
    this.applyOrgLabels()
    this.reset(this.departmentTarget, "All")
    this.reset(this.unitTarget, "All Units")
    await this.fill(this.divisionTarget, "All", "/lookups/divisions?agency=", this.agencyTarget.value)
  }

  async loadDepartments() {
    this.reset(this.unitTarget, "All Units")
    await this.fill(this.departmentTarget, "All", "/lookups/departments?division=", this.divisionTarget.value)
  }

  async loadUnits() {
    await this.fill(this.unitTarget, "All Units", "/lookups/units?department=", this.departmentTarget.value)
  }

  // Relabels the two middle levels for the selected agency — HCA's vocabulary
  // reverses division and department. Only the label text changes; the fields
  // keep their names and values.
  applyOrgLabels() {
    const config = this.orgLabelsValue
    if (!config?.canonical) return

    const agency = (this.hasAgencyTarget ? this.agencyTarget.value : "").trim().toUpperCase()
    const labels = (config.swappedAgencyIds || []).includes(agency) ? config.swapped : config.canonical

    if (this.hasDivisionLabelTarget) this.divisionLabelTarget.textContent = labels.division
    if (this.hasDepartmentLabelTarget) this.departmentLabelTarget.textContent = labels.department
  }

  // A level with nothing chosen above it holds only its blank option, so it
  // reads as "all" rather than as a list that failed to load.
  reset(select, blankLabel) {
    if (!select) return

    select.innerHTML = ""
    select.appendChild(this.option("", blankLabel))
  }

  // Refills one level from its parent's value. Nothing chosen above means
  // there is no list to ask for, and the level stays at "all".
  async fill(select, blankLabel, path, parentValue) {
    if (!select) return

    const parent = (parentValue || "").trim()
    this.reset(select, parent ? "Loading…" : blankLabel)
    if (!parent) return

    try {
      const response = await fetch(path + encodeURIComponent(parent), { headers: { Accept: "application/json" } })
      const pairs = response.ok ? await response.json() : []
      this.reset(select, blankLabel)
      pairs.forEach(([label, value]) => select.appendChild(this.option(value, label)))
    } catch {
      // A failed lookup leaves the level at "all" rather than stuck on
      // "Loading…", so the search still runs — just one level wider.
      this.reset(select, blankLabel)
    }
  }

  option(value, label) {
    const option = document.createElement("option")
    option.value = value
    option.textContent = label
    return option
  }
}
