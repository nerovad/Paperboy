// app/javascript/controllers/advanced_search_controller.js
//
// The Advanced Search panel in the Paperboy sidebar.
//
// It narrows the list of forms you can *fill out* by the metadata an admin set
// on each one in the form builder — owning organization, form type, tags. The
// sidebar has already rendered every form the viewer is allowed to use, each
// link carrying its own metadata, so filtering is a pass over the DOM rather
// than a request: instant, and it survives being reopened and adjusted.
//
// It shares the list with sidebar_search_controller.js, which matches text.
// The two compose: this one marks a link `data-facet-hidden`, and the text
// search treats that as final. Neither has to know what the other matched on.
//
// The org selects are the shared cascade (org_cascade_controller.js), except
// that the levels are filled from an org tree rendered into the page rather
// than fetched from /lookups — the tree holds only the orgs that actually own
// a form, so the panel can never offer a choice that finds nothing.
import OrgCascadeController from "controllers/org_cascade_controller"

const STORAGE_KEY = "paperboy.form-facets"

export default class extends OrgCascadeController {
  static targets = ["modal", "trigger", "formLink", "formType", "tag"]

  // { agencies: [[label, code], …], divisions: { agencyCode: [[label, code], …] }, … }
  static values = { orgTree: Object }

  connect() {
    super.connect()
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.restore()
    this.filterLinks()
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
  // the panel are the user working inside it.
  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }

  apply() {
    this.persist()
    this.filterLinks()
    this.close()
  }

  // Empties the panel and widens the list again, but leaves the panel open so
  // the user can see it has been emptied and start a different search.
  clear() {
    if (this.agencySelect) this.agencySelect.value = ""
    this.loadDivisions()
    this.formTypeTargets.concat(this.tagTargets).forEach(box => { box.checked = false })
    this.persist()
    this.filterLinks()
  }

  // --- The cascade, read from the page instead of /lookups -------------------

  loadDivisions() {
    this.applyOrgLabels()
    this.fillFromTree(this.departmentSelect, "departments", "")
    this.fillFromTree(this.unitSelect, "units", "")
    this.fillFromTree(this.divisionSelect, "divisions", this.value(this.agencySelect))
  }

  loadDepartments() {
    this.fillFromTree(this.unitSelect, "units", "")
    this.fillFromTree(this.departmentSelect, "departments", this.value(this.divisionSelect))
  }

  loadUnits() {
    this.fillFromTree(this.unitSelect, "units", this.value(this.departmentSelect))
  }

  // One level's options, looked up in the tree by the code chosen above it.
  // No parent chosen means there is no list to offer and the level stays at
  // "any", which is what an empty select already means here.
  fillFromTree(select, level, parentCode) {
    if (!select) return

    this.reset(select, this.blankLabel(select))
    const branches = this.orgTreeValue?.[level] || {}
    const options = parentCode ? branches[parentCode] || [] : []
    options.forEach(([label, code]) => select.appendChild(this.option(code, label)))
  }

  // --- Filtering -------------------------------------------------------------

  // What the panel is currently asking for. A blank select or an unticked set
  // of boxes means "any", and drops out of the test entirely.
  criteria() {
    return {
      agency: this.value(this.agencySelect),
      division: this.value(this.divisionSelect),
      department: this.value(this.departmentSelect),
      unit: this.value(this.unitSelect),
      formTypes: this.checked(this.formTypeTargets),
      tags: this.checked(this.tagTargets)
    }
  }

  filterLinks() {
    const criteria = this.criteria()
    const filtering = Object.values(criteria).some(value => value.length > 0)

    this.formLinkTargets.forEach(link => {
      link.dataset.facetHidden = this.matches(link, criteria) ? "false" : "true"
    })

    if (this.hasTriggerTarget) this.triggerTarget.classList.toggle("has-filters", filtering)

    // The text search owns what is finally shown, so it re-runs over the marks
    // just made. Before it has connected there is nothing to defer to, and the
    // marks are applied directly instead.
    const search = this.textSearch
    if (search) search.filter()
    else this.formLinkTargets.forEach(link => { link.style.display = link.dataset.facetHidden === "true" ? "none" : "" })
  }

  // Every set filter has to be satisfied, but any one of the ticked values
  // within a filter will do — "a Request or a Report, filed by HCA".
  //
  // A form with no metadata at all matches nothing once a filter is set. It
  // cannot answer the question being asked, and letting it through would make
  // "forms issued by HCA" quietly mean "…and every untagged form".
  matches(link, criteria) {
    return this.matchesOne(link.dataset.agency, criteria.agency) &&
      this.matchesOne(link.dataset.division, criteria.division) &&
      this.matchesOne(link.dataset.department, criteria.department) &&
      this.matchesOne(link.dataset.unit, criteria.unit) &&
      this.matchesAny([link.dataset.formType], criteria.formTypes) &&
      this.matchesAny(this.list(link.dataset.tags), criteria.tags)
  }

  matchesOne(value, wanted) {
    return wanted === "" || value === wanted
  }

  matchesAny(values, wanted) {
    return wanted.length === 0 || values.some(value => wanted.includes(value))
  }

  // --- State -----------------------------------------------------------------

  // Facets outlive a full page load, because the sidebar is redrawn by every
  // one of them and a narrowed list that silently widened again would read as
  // the filter having failed. Session-scoped, so a new tab starts clean.
  persist() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(this.criteria()))
    } catch {
      // A browser that refuses storage still filters; the choice just does not
      // survive the next page load.
    }
  }

  restore() {
    let saved = null
    try {
      saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) || "null")
    } catch {
      saved = null
    }
    if (!saved) return

    // Each level is filled from the one above before its own value is set, and
    // a code that is no longer offered simply leaves that level at "any".
    this.select(this.agencySelect, saved.agency)
    this.applyOrgLabels()
    this.fillFromTree(this.divisionSelect, "divisions", this.value(this.agencySelect))
    this.select(this.divisionSelect, saved.division)
    this.fillFromTree(this.departmentSelect, "departments", this.value(this.divisionSelect))
    this.select(this.departmentSelect, saved.department)
    this.fillFromTree(this.unitSelect, "units", this.value(this.departmentSelect))
    this.select(this.unitSelect, saved.unit)

    this.check(this.formTypeTargets, saved.formTypes)
    this.check(this.tagTargets, saved.tags)
  }

  // --- Small helpers ---------------------------------------------------------

  // The org fieldset is left out entirely when no form is tied to an org, so
  // every level is reached through a getter that tolerates its absence rather
  // than through the target, which would throw.
  get agencySelect() { return this.hasAgencyTarget ? this.agencyTarget : null }

  get divisionSelect() { return this.hasDivisionTarget ? this.divisionTarget : null }

  get departmentSelect() { return this.hasDepartmentTarget ? this.departmentTarget : null }

  get unitSelect() { return this.hasUnitTarget ? this.unitTarget : null }

  value(select) {
    return (select?.value || "").trim()
  }

  select(target, value) {
    if (target && value) target.value = value
  }

  checked(boxes) {
    return boxes.filter(box => box.checked).map(box => box.value)
  }

  check(boxes, values) {
    const wanted = values || []
    boxes.forEach(box => { box.checked = wanted.includes(box.value) })
  }

  list(csv) {
    return (csv || "").split(",").map(value => value.trim()).filter(Boolean)
  }

  get textSearch() {
    return this.application.getControllerForElementAndIdentifier(this.element, "sidebar-search")
  }
}
