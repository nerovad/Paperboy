import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  enableAll() {
    this.selectReports("1")
  }

  disableAll() {
    this.selectReports("0")
  }

  enableAllRecipients() {
    this.selectRecipients("1")
  }

  disableAllRecipients() {
    this.selectRecipients("0")
  }

  resetRecipients() {
    this.element.querySelectorAll('input[type="radio"][name^="recipients["]').forEach((input) => {
      input.checked = input.defaultChecked
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  selectReports(value) {
    this.selectValues("reports", value)
  }

  selectRecipients(value) {
    this.selectValues("recipients", value)
  }

  selectValues(group, value) {
    const selector = `input[type="radio"][name^="${group}["][value="${value}"]`

    this.element.querySelectorAll(selector).forEach((input) => {
      input.checked = true
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }
}
