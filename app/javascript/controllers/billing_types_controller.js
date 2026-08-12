import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  enableAll() {
    this.selectValue("1")
  }

  disableAll() {
    this.selectValue("0")
  }

  selectValue(value) {
    this.element.querySelectorAll(`input[type="radio"][value="${value}"]`).forEach((input) => {
      input.checked = true
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }
}
