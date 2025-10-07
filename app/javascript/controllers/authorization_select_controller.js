import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["serviceType", "keyType"]

  connect() {
    // Check initial state on page load
    this.toggleKeyType()
  }

  toggleKeyType() {
    const keyTypeWrapper = document.getElementById("key-type-wrapper")
    const selectedValue = this.serviceTypeTarget.value

    if (selectedValue === "K") {
      keyTypeWrapper.style.display = "block"
      this.keyTypeTarget.required = true
    } else {
      keyTypeWrapper.style.display = "none"
      this.keyTypeTarget.required = false
      this.keyTypeTarget.value = "" // Clear selection when hidden
    }
  }
}
