import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["serviceType", "keyTypeWrapper", "keyType", "locationsWrapper"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    const selectedValue = this.serviceTypeTarget.value
    const isKeyService = selectedValue === "K"

    // Show/hide key type
    this.keyTypeWrapperTarget.style.display = isKeyService ? "block" : "none"

    // Show/hide locations
    this.locationsWrapperTarget.style.display = isKeyService ? "block" : "none"

    // Required only when keys are chosen
    this.keyTypeTarget.required = isKeyService

    // Clear selection when hidden
    if (!isKeyService) {
      this.keyTypeTarget.value = ""
    }
  }
}
