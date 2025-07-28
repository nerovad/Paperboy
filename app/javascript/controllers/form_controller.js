import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["page", "dot", "submitButton", "vehicleWrapper", "vehicleTemplate"]

  connect() {
    this.currentPage = 0
    this.vehicleIndex = 1
    this.showPage(this.currentPage)
  }

  showPage(index) {
    this.pageTargets.forEach((el, i) => {
      el.style.display = i === index ? "block" : "none"
    })

    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("active", i === index)
    })

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.style.display = index === this.pageTargets.length - 1 ? "inline-block" : "none"
    }
  }

  nextPage() {
    if (this.currentPage < this.pageTargets.length - 1) {
      this.currentPage++
      this.showPage(this.currentPage)
    }
  }

  prevPage() {
    if (this.currentPage > 0) {
      this.currentPage--
      this.showPage(this.currentPage)
    }
  }

  addVehicle() {
    const html = this.vehicleTemplateTarget.innerHTML.replace(/NEW_RECORD/g, this.vehicleIndex++)
    this.vehicleWrapperTarget.insertAdjacentHTML("beforeend", html)
  }

  removeVehicle(event) {
    event.target.closest(".vehicle-fields")?.remove()
  }

  handleParkingLotChange(event) {
    const group = event.target.closest(".vehicle-fields")
    const otherInput = group.querySelector(".other-lot-field")

    if (event.target.value === "Other") {
      otherInput.style.display = "block"
    } else {
      otherInput.style.display = "none"
      otherInput.value = ""
    }
  }
}
