import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox"]

  toggle() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
  }

  update() {
    this.selectAllTarget.checked = this.checkboxTargets.every(cb => cb.checked)
  }
}
