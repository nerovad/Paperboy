// app/javascript/controllers/org_cascade_controller.js
//
// The county org cascade: Agency → Division → Department → Unit, where each
// list depends on the one above it and only the server knows the codes.
//
// Lists come from /lookups as JSON rather than the turbo_stream responses
// gsabss_selects_controller.js uses, because those replace fixed DOM ids and so
// can only appear once on a page — this one can be rendered anywhere, as many
// times as needed. Render it with the shared "shared/org_cascade" partial.
//
// advanced_search_controller.js subclasses this and adds the sidebar panel's
// open/close behaviour on top, so the two cascades can never drift apart.
import { Controller } from "@hotwired/stimulus"

export default class OrgCascadeController extends Controller {
  static targets = ["agency", "division", "department", "unit",
                    "divisionLabel", "departmentLabel"]

  // { swappedAgencyIds: [...], canonical: {...}, swapped: {...} } — rendered
  // from OrgLabels so the Ruby and JS vocabularies can't drift.
  static values = { orgLabels: Object }

  connect() {
    this.applyOrgLabels()
  }

  // Each level clears everything below it: a division that belonged to the old
  // agency is not a narrower version of the new one, it is simply wrong.
  async loadDivisions() {
    this.applyOrgLabels()
    this.reset(this.departmentTarget, this.blankLabel(this.departmentTarget))
    this.reset(this.unitTarget, this.blankLabel(this.unitTarget))
    await this.fill(this.divisionTarget, "/lookups/divisions?agency=", this.agencyTarget.value)
  }

  async loadDepartments() {
    this.reset(this.unitTarget, this.blankLabel(this.unitTarget))
    await this.fill(this.departmentTarget, "/lookups/departments?division=", this.divisionTarget.value)
  }

  async loadUnits() {
    await this.fill(this.unitTarget, "/lookups/units?department=", this.departmentTarget.value)
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

  // The wording a level uses when nothing is chosen ("All Units"), carried on
  // the select itself so the partial owns the copy and this controller doesn't.
  blankLabel(select) {
    return select?.dataset.blankLabel || "All"
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
  async fill(select, path, parentValue) {
    if (!select) return

    const blankLabel = this.blankLabel(select)
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
      // "Loading…", so the form still works — just one level wider.
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
