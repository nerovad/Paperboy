import { Controller } from "@hotwired/stimulus"

// Acknowledge rejected and deleted invoices (#169): tick rows, or the
// heading's box for every row the page's search leaves (on every page, as
// Move selected does), then Acknowledge selected. The boxes belong to the
// bulk form through their form= attribute, so each row can keep its own
// one-click Acknowledge button.
export default class extends Controller {
  static targets = ["check", "button", "count"]

  selectAll(event) {
    this.checkTargets.forEach((box) => {
      if (box.closest("tr").dataset.match !== "0") box.checked = event.currentTarget.checked
    })
    this.count()
  }

  count() {
    const n = this.checkTargets.filter((box) => box.checked).length
    this.countTarget.textContent = n
    this.buttonTarget.disabled = n === 0
  }
}
