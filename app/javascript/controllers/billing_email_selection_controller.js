import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  enableAll() {
    this.selectReports("1")
  }

  disableAll() {
    this.selectReports("0")
  }

  selectReports(value) {
    const selector = `input[type="radio"][name^="reports["][value="${value}"]`

    this.element.querySelectorAll(selector).forEach((input) => {
      input.checked = true
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }
}
