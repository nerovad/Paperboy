import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper", "template"]

  connect() {
    this.vehicleIndex = this.wrapperTarget.querySelectorAll(".vehicle-fields").length
  }

  add() {
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.vehicleIndex)
    this.wrapperTarget.insertAdjacentHTML("beforeend", html)
    this.vehicleIndex++
  }

  remove(event) {
    if (!event.target.classList.contains("remove-vehicle-btn")) return
    event.target.closest(".vehicle-fields")?.remove()
  }

  toggleOtherLot(event) {
    if (!event.target.classList.contains("parking-lot-select")) return
    const group = event.target.closest(".vehicle-fields")
    const otherInput = group?.querySelector(".other-lot-field")
    if (!otherInput) return
    if (event.target.value === "Other") {
      otherInput.style.display = "block"
    } else {
      otherInput.style.display = "none"
      otherInput.value = ""
    }
  }
}
