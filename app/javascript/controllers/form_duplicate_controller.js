import { Controller } from "@hotwired/stimulus"

// Duplicate dialog on the form templates index (form_templates/_duplicate_modal).
//
// One dialog serves every card: each Duplicate button passes its template's
// preview and submit URLs as action params. The server owns every answer —
// what the new name renames to, what each box would copy, whether the set is
// valid — so this asks duplicate_preview whenever the name or the ticks
// change and renders what comes back.
//
// Ticking a box also ticks what it needs (a controller needs its model and
// views); unticking one unticks whatever needed it. The server refuses a set
// that breaks this anyway, so the dialog only saves a round of errors.
export default class extends Controller {
  static targets = ["backdrop", "sourceName", "name", "renames", "renameRows", "errors",
                    "selectAll", "component", "checkbox", "items", "submitButton"]

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape" && !this.backdropTarget.hidden) this.close() }
    document.addEventListener("keydown", this._escHandler)
    this.backdropTarget.addEventListener("click", (e) => {
      if (e.target === this.backdropTarget) this.close()
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler)
    clearTimeout(this._debounce)
  }

  open({ params }) {
    this.previewUrl = params.previewUrl
    this.submitUrl = params.submitUrl
    this.sourceNameTarget.textContent = params.source
    this.nameTarget.value = ""
    this.unavailable = new Set()
    this.checkboxTargets.forEach(cb => { cb.checked = this.isLocked(cb) })
    this.syncSelectAll()
    this.showErrors([])
    this.submitting = false
    this.submitButtonTarget.textContent = "Duplicate"
    this.backdropTarget.hidden = false
    setTimeout(() => this.nameTarget.focus(), 0)
    this.refresh()
  }

  close() {
    if (this.submitting) return
    this.backdropTarget.hidden = true
  }

  nameChanged() {
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this.refresh(), 300)
  }

  toggleAll() {
    const on = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => {
      if (this.isLocked(cb) || this.isUnavailable(cb)) return
      cb.checked = on
    })
    this.refresh()
  }

  componentChanged(event) {
    const box = event.target
    if (box.checked) {
      this.tickRequirements(box)
    } else {
      this.untickDependents(box.value)
    }
    this.syncSelectAll()
    this.refresh()
  }

  async submit() {
    if (this.submitting || this.submitButtonTarget.disabled) return

    this.submitting = true
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Duplicating…"
    this.showErrors([])

    try {
      const response = await fetch(this.submitUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ name: this.nameTarget.value, components: this.chosen() })
      })
      const data = await response.json()
      if (data.success) {
        window.location.href = data.redirect
        return
      }
      this.showErrors(data.errors || ["The copy could not be made."])
    } catch (error) {
      this.showErrors([`The copy could not be made: ${error.message}`])
    }

    this.submitting = false
    this.submitButtonTarget.textContent = "Duplicate"
    this.refresh()
  }

  // --- Preview -------------------------------------------------------------

  async refresh() {
    if (!this.previewUrl) return

    const url = new URL(this.previewUrl, window.location.origin)
    url.searchParams.set("name", this.nameTarget.value)
    this.chosen().forEach(key => url.searchParams.append("components[]", key))

    const requestId = (this._requestId = (this._requestId || 0) + 1)
    let data
    try {
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      data = await response.json()
    } catch (error) {
      this.showErrors([`Could not load the preview: ${error.message}`])
      return
    }
    // A slower, older answer must not overwrite a newer one.
    if (requestId !== this._requestId) return

    this.renderRenames(data.identity || [])
    this.renderComponents(data.components || {})
    const typed = this.nameTarget.value.trim() !== ""
    this.showErrors(typed ? data.errors : [])
    this.submitButtonTarget.disabled = this.submitting || !data.valid
  }

  renderRenames(rows) {
    const named = rows.some(([, , to]) => to)
    this.renamesTarget.hidden = !named
    this.renameRowsTarget.replaceChildren(...rows.map(([label, from, to]) => {
      const tr = document.createElement("tr")
      tr.append(this.cell("th", label), this.cell("td", from, true), this.cell("td", to || "…", true))
      return tr
    }))
  }

  renderComponents(components) {
    this.unavailable = new Set()
    this.componentTargets.forEach(row => {
      const key = row.dataset.key
      const info = components[key] || { available: true, items: [] }
      const box = this.checkboxTargets.find(cb => cb.value === key)
      const list = this.itemsTargets.find(ul => ul.dataset.key === key)

      if (!info.available) this.unavailable.add(key)
      row.classList.toggle("is-unavailable", !info.available)
      if (!this.isLocked(box)) {
        box.disabled = !info.available
        if (!info.available) box.checked = false
      }

      const items = info.available ? info.items : ["Nothing to copy for this form."]
      list.replaceChildren(...items.map(text => {
        const li = document.createElement("li")
        li.textContent = text
        return li
      }))
    })
    this.syncSelectAll()
  }

  // --- Ticks ---------------------------------------------------------------

  chosen() {
    return this.checkboxTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  tickRequirements(box) {
    this.requirementsOf(box).forEach(key => {
      const needed = this.box(key)
      if (!needed || needed.checked || this.isUnavailable(needed)) return
      needed.checked = true
      this.tickRequirements(needed)
    })
  }

  untickDependents(key) {
    this.checkboxTargets.forEach(cb => {
      if (!cb.checked || this.isLocked(cb) || !this.requirementsOf(cb).includes(key)) return
      cb.checked = false
      this.untickDependents(cb.value)
    })
  }

  syncSelectAll() {
    const choosable = this.checkboxTargets.filter(cb => !this.isLocked(cb) && !this.isUnavailable(cb))
    this.selectAllTarget.checked = choosable.length > 0 && choosable.every(cb => cb.checked)
  }

  requirementsOf(box) {
    return (box.dataset.requires || "").split(" ").filter(Boolean)
  }

  box(key) {
    return this.checkboxTargets.find(cb => cb.value === key)
  }

  isLocked(box) {
    return box.dataset.locked === "true"
  }

  isUnavailable(box) {
    return this.unavailable && this.unavailable.has(box.value)
  }

  // --- Output --------------------------------------------------------------

  cell(tag, text, code = false) {
    const el = document.createElement(tag)
    if (tag === "th") el.scope = "row"
    if (code && text !== "…") {
      const c = document.createElement("code")
      c.textContent = text
      el.append(c)
    } else {
      el.textContent = text
    }
    return el
  }

  showErrors(errors) {
    const list = (errors || []).filter(Boolean)
    this.errorsTarget.hidden = list.length === 0
    const ul = document.createElement("ul")
    list.forEach(message => {
      const li = document.createElement("li")
      li.textContent = message
      ul.append(li)
    })
    this.errorsTarget.replaceChildren(ul)
  }
}
