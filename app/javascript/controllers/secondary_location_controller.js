import { Controller } from "@hotwired/stimulus"

// Progressive disclosure for a vehicle's optional second garaging site: the
// dropdown stays collapsed behind "+ Add secondary garaging location" until
// it's actually needed.
export default class extends Controller {
  static targets = ["addBtn", "field", "select"]

  connect() {
    // vehicle-list#handleAdd clones #vehicle-template's innerHTML verbatim, so
    // leave the template's markup in its pristine collapsed state — every added
    // row inherits it. Mirrors the guard in choices_controller/nhtsa_vehicle.
    if (this.element.closest("#vehicle-template")) return

    // Edit mode: a saved secondary location means this row starts expanded.
    if (this.hasSelectTarget && this.selectTarget.value) this.show()
  }

  show() {
    if (!this.hasFieldTarget) return
    this.fieldTarget.style.display = ""
    if (this.hasAddBtnTarget) this.addBtnTarget.style.display = "none"
  }

  hide() {
    if (!this.hasFieldTarget) return
    this.fieldTarget.style.display = "none"
    if (this.hasAddBtnTarget) this.addBtnTarget.style.display = ""
    this.#clearSelection()
  }

  // Collapsing discards the choice, so the row doesn't submit a location the
  // user can no longer see. Clear through the Choices instance first — writing
  // select.value alone would leave the rendered label showing the stale
  // building if they re-open the field.
  #clearSelection() {
    if (!this.hasSelectTarget) return

    const host = this.selectTarget.closest('[data-controller~="choices"]')
    const choices =
      host &&
      this.application.getControllerForElementAndIdentifier(host, "choices")
        ?.choices

    if (choices && typeof choices.removeActiveItems === "function") {
      choices.removeActiveItems()
      choices.setChoiceByValue("")
    }
    this.selectTarget.value = ""
  }
}
