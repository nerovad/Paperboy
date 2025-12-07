// app/javascript/controllers/sidebar_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "formLink"]

  filter() {
    const searchTerm = this.inputTarget.value.toLowerCase().trim()

    this.formLinkTargets.forEach(link => {
      const formName = link.textContent.toLowerCase()

      if (searchTerm === "" || formName.includes(searchTerm)) {
        link.style.display = ""
      } else {
        link.style.display = "none"
      }
    })
  }
}
