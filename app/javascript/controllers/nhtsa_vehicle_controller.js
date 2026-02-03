// app/javascript/controllers/nhtsa_vehicle_controller.js
import { Controller } from "@hotwired/stimulus"

// Module-level caches shared across all controller instances
let makesPromise = null
const modelsCache = {}

const ACRONYM_MAKES = new Set(["BMW", "GMC", "RAM", "MINI", "FIAT", "MG", "TVR", "SRT"])

function titleCase(str) {
  if (ACRONYM_MAKES.has(str.toUpperCase())) return str.toUpperCase()
  return str
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase())
}

function fetchMakes() {
  if (makesPromise) return makesPromise

  makesPromise = fetch("/api/nhtsa/makes")
    .then((r) => {
      if (!r.ok) throw new Error(`NHTSA proxy error: ${r.status}`)
      return r.json()
    })
    .then((results) => {
      if (results.error) throw new Error(results.error)
      const makes = results.map((m) => ({
        value: titleCase(m.MakeName),
        label: titleCase(m.MakeName),
      }))
      makes.sort((a, b) => a.label.localeCompare(b.label))
      return makes
    })
    .catch((err) => {
      makesPromise = null
      throw err
    })

  return makesPromise
}

function fetchModels(make, year) {
  const key = `${make.toUpperCase()}-${year}`
  if (modelsCache[key]) return Promise.resolve(modelsCache[key])

  return fetch(`/api/nhtsa/models?make=${encodeURIComponent(make)}&year=${encodeURIComponent(year)}`)
    .then((r) => {
      if (!r.ok) throw new Error(`NHTSA proxy error: ${r.status}`)
      return r.json()
    })
    .then((results) => {
      if (results.error) throw new Error(results.error)
      const models = results.map((m) => ({
        value: m.Model_Name,
        label: m.Model_Name,
      }))
      models.sort((a, b) => a.label.localeCompare(b.label))
      modelsCache[key] = models
      return models
    })
}

export default class extends Controller {
  static targets = [
    "year",
    "make",
    "model",
    "hiddenMake",
    "hiddenModel",
    "otherMake",
    "otherModel",
  ]

  connect() {
    if (this.element.closest("#vehicle-template")) return

    this.makeChoices = null
    this.modelChoices = null

    this._createMakeChoices()
    this._createModelChoices()
  }

  disconnect() {
    this._destroyMakeChoices()
    this._destroyModelChoices()
  }

  // --- Actions ---

  yearChanged() {
    const year = this.yearTarget.value
    if (!year) return

    // Disable both while loading
    this.hiddenMakeTarget.value = ""
    this.hiddenModelTarget.value = ""
    this._hideOtherMake()
    this._hideOtherModel()
    if (this.makeChoices) this.makeChoices.disable()
    if (this.modelChoices) this.modelChoices.disable()

    this._loadMakes()
  }

  makeChanged() {
    const selected = this.makeTarget.value

    if (selected === "__other__") {
      this._showOtherMake()
      this._showOtherModel()
      return
    }

    this.hiddenMakeTarget.value = selected
    this._hideOtherMake()
    this._hideOtherModel()

    // Reset model
    this.hiddenModelTarget.value = ""
    if (this.modelChoices) this.modelChoices.disable()

    const year = this.yearTarget.value
    if (!year || !selected) return

    this._loadModels(selected, year)
  }

  modelChanged() {
    const selected = this.modelTarget.value

    if (selected === "__other__") {
      this._showOtherModel()
      return
    }

    this.hiddenModelTarget.value = selected
    this._hideOtherModel()
  }

  otherMakeTyped() {
    this.hiddenMakeTarget.value = this.otherMakeTarget.value
  }

  otherModelTyped() {
    this.hiddenModelTarget.value = this.otherModelTarget.value
  }

  // --- Private: Choices.js lifecycle ---

  _destroyMakeChoices() {
    if (this.makeChoices) {
      this.makeChoices.destroy()
      this.makeChoices = null
    }
  }

  _destroyModelChoices() {
    if (this.modelChoices) {
      this.modelChoices.destroy()
      this.modelChoices = null
    }
  }

  _createMakeChoices(disabled = true) {
    this._destroyMakeChoices()
    const C = window.Choices
    if (!C || !this.hasMakeTarget) return

    this.makeTarget.disabled = false
    this.makeChoices = new C(this.makeTarget, {
      shouldSort: false,
      searchEnabled: true,
      allowHTML: false,
      placeholder: true,
      placeholderValue: "Search Make...",
      noResultsText: "No makes found",
      noChoicesText: "Select a Year first",
    })
    if (disabled) this.makeChoices.disable()
  }

  _createModelChoices(disabled = true) {
    this._destroyModelChoices()
    const C = window.Choices
    if (!C || !this.hasModelTarget) return

    this.modelTarget.disabled = false
    this.modelChoices = new C(this.modelTarget, {
      shouldSort: false,
      searchEnabled: true,
      allowHTML: false,
      placeholder: true,
      placeholderValue: "Search Model...",
      noResultsText: "No models found",
      noChoicesText: "Select a Make first",
    })
    if (disabled) this.modelChoices.disable()
  }

  // --- Private: populate native <select> then wrap with Choices.js ---

  _populateSelect(selectEl, items, placeholder) {
    selectEl.innerHTML = ""

    const ph = document.createElement("option")
    ph.value = ""
    ph.textContent = placeholder
    ph.disabled = true
    ph.selected = true
    selectEl.appendChild(ph)

    items.forEach((item) => {
      const opt = document.createElement("option")
      opt.value = item.value
      opt.textContent = item.label
      selectEl.appendChild(opt)
    })

    const other = document.createElement("option")
    other.value = "__other__"
    other.textContent = "Other (type manually)"
    selectEl.appendChild(other)
  }

  _loadMakes() {
    fetchMakes()
      .then((makes) => {
        // Populate the native <select> first, then wrap with Choices.js
        this._destroyMakeChoices()
        this._populateSelect(this.makeTarget, makes, "Select Make")

        try {
          this._createMakeChoices(false)
        } catch (err) {
          console.error("NHTSA: Choices.js error on make dropdown", err)
          this.makeTarget.disabled = false
        }
      })
      .catch((err) => {
        console.error("NHTSA: Failed to fetch makes", err)
        this._fallbackToText()
      })
  }

  _loadModels(make, year) {
    fetchModels(make, year)
      .then((models) => {
        this._destroyModelChoices()
        this._populateSelect(this.modelTarget, models, "Select Model")

        try {
          this._createModelChoices(false)
        } catch (err) {
          console.error("NHTSA: Choices.js error on model dropdown", err)
          this.modelTarget.disabled = false
        }
      })
      .catch((err) => {
        console.error("NHTSA: Failed to fetch models", err)
        this._showOtherModel()
      })
  }

  // --- Private: Other text fields ---

  _showOtherMake() {
    this.otherMakeTarget.style.display = ""
    this.otherMakeTarget.focus()
    this.hiddenMakeTarget.value = this.otherMakeTarget.value
    if (this.makeChoices) this.makeChoices.disable()
    else this.makeTarget.disabled = true
  }

  _hideOtherMake() {
    this.otherMakeTarget.style.display = "none"
    this.otherMakeTarget.value = ""
  }

  _showOtherModel() {
    this.otherModelTarget.style.display = ""
    this.otherModelTarget.focus()
    this.hiddenModelTarget.value = this.otherModelTarget.value
    if (this.modelChoices) this.modelChoices.disable()
    else this.modelTarget.disabled = true
  }

  _hideOtherModel() {
    this.otherModelTarget.style.display = "none"
    this.otherModelTarget.value = ""
  }

  _fallbackToText() {
    this._destroyMakeChoices()
    this._destroyModelChoices()
    this.makeTarget.style.display = "none"
    this.modelTarget.style.display = "none"
    this._showOtherMake()
    this._showOtherModel()
  }
}
