import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.wrapper = document.getElementById("vehicle-wrapper")
    this.template = document.getElementById("vehicle-template")
    this.addBtn = document.getElementById("add-vehicle")
    if (!this.wrapper || !this.template || !this.addBtn) return

    this.vehicleIndex = this.wrapper.querySelectorAll(".vehicle-fields").length

    this.handleAdd = () => {
      const html = this.template.innerHTML.replace(/NEW_RECORD/g, this.vehicleIndex)
      this.wrapper.insertAdjacentHTML("beforeend", html)
      this.vehicleIndex++
    }

    this.handleRemove = (event) => {
      if (!event.target.classList.contains("remove-vehicle-btn")) return
      event.target.closest(".vehicle-fields")?.remove()
    }

    this.addBtn.addEventListener("click", this.handleAdd)
    this.wrapper.addEventListener("click", this.handleRemove)
  }

  disconnect() {
    this.addBtn?.removeEventListener("click", this.handleAdd)
    this.wrapper?.removeEventListener("click", this.handleRemove)
  }
}
