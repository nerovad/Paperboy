import { Controller } from "@hotwired/stimulus"
import Choices from "choices.js"

export default class extends Controller {
  static targets = ["multiSelect", "otherGroup"]

  connect() {
     console.log("Stimulus controller connected: ProbationTransferRequestController");
    this.choices = new Choices(this.multiSelectTarget, {
      removeItemButton: true,
      placeholderValue: "Select Destination(s)",
      shouldSort: false
    })

    this.multiSelectTarget.addEventListener("change", () => this.toggleOtherField())
    this.toggleOtherField()
  }

  toggleOtherField() {
    const values = Array.from(this.multiSelectTarget.selectedOptions).map(opt => opt.value)
    this.otherGroupTarget.style.display = values.includes("Other") ? "block" : "none"
  }
}
