// app/javascript/controllers/dam_search_controller.js
//
// The Advanced Search modal in the DAM sidebar.
//
// Two jobs: open and close the dialog, and keep each custom-metadata row
// coherent — the operators a field offers and the inputs an operator needs
// both depend on the field's type, which only the server knows. That registry
// arrives as JSON on the sidebar element (fieldsValue).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", "metaRows", "rowTemplate",
    "metaRow", "metaField", "metaOperator", "metaValue", "metaValueTo",
  ]

  static values = { fields: Array }

  // Operators that compare against nothing, so their value boxes are hidden
  // rather than left blank — a blank box next to "is present" reads as an
  // input you forgot to fill in.
  static VALUELESS = ["present", "blank"]

  connect() {
    this.rowIndex = this.metaRowTargets.length
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.style.overflow = ""
  }

  open() {
    this.modalTarget.hidden = false
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.closeOnEscape)
    // Escape is bound on the document rather than the dialog so it works
    // before anything inside has been focused.
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

  addFilter() {
    if (!this.hasRowTemplateTarget) return

    const markup = this.rowTemplateTarget.innerHTML.replaceAll("__INDEX__", this.rowIndex)
    this.rowIndex += 1

    const holder = document.createElement("div")
    holder.innerHTML = markup.trim()
    const row = holder.firstElementChild
    this.metaRowsTarget.appendChild(row)
    this.syncRow(row)
  }

  removeFilter(event) {
    event.target.closest(".dam-meta-row")?.remove()
  }

  fieldChanged(event) {
    const row = event.target.closest(".dam-meta-row")
    const field = this.fieldFor(row)
    if (!field) return

    // A new field brings a new operator list, so the old selection is replaced
    // rather than preserved — "contains" is meaningless on a date.
    const operatorSelect = row.querySelector(".dam-meta-operator")
    operatorSelect.innerHTML = ""
    field.operators.forEach((operator) => {
      const option = document.createElement("option")
      option.value = operator
      option.textContent = operator.replaceAll("_", " ").replace(/^./, (c) => c.toUpperCase())
      operatorSelect.appendChild(option)
    })

    this.syncRow(row)
  }

  operatorChanged(event) {
    this.syncRow(event.target.closest(".dam-meta-row"))
  }

  // Makes the value inputs match the chosen field and operator: right input
  // type, right number of boxes, right choices for a select field.
  syncRow(row) {
    if (!row) return

    const field = this.fieldFor(row)
    const operator = row.querySelector(".dam-meta-operator")?.value
    const value = row.querySelector(".dam-meta-value")
    const valueTo = row.querySelector(".dam-meta-value-to")
    if (!field || !value) return

    const valueless = this.constructor.VALUELESS.includes(operator)
    value.hidden = valueless
    valueTo.hidden = valueless || operator !== "between"

    const inputType = field.type === "number" ? "number" : field.type === "date" ? "date" : "text"
    value.type = inputType
    valueTo.type = inputType

    this.applyChoices(value, field)
  }

  // A select field gets a datalist rather than a <select>, so the row keeps one
  // markup shape across all four field types and an operator like "not equals"
  // still accepts a value that is no longer in the choice list.
  applyChoices(input, field) {
    const listId = `${input.name.replaceAll(/[^a-z0-9]/gi, "-")}-choices`
    document.getElementById(listId)?.remove()
    input.removeAttribute("list")

    if (field.type !== "select" || !field.choices?.length) return

    const list = document.createElement("datalist")
    list.id = listId
    field.choices.forEach((choice) => {
      const option = document.createElement("option")
      option.value = choice
      list.appendChild(option)
    })
    input.after(list)
    input.setAttribute("list", listId)
  }

  fieldFor(row) {
    const key = row?.querySelector(".dam-meta-field")?.value
    return this.fieldsValue.find((field) => field.key === key)
  }
}
