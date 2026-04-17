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
}
