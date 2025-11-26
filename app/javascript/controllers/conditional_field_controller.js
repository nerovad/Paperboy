// app/javascript/controllers/conditional_field_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selectedValue = this.triggerTarget.value

    this.fieldTargets.forEach(field => {
      const showWhen = field.dataset.showWhen

      if (selectedValue === showWhen) {
        field.style.display = "block"
        // Make field required when visible
        const input = field.querySelector('input, select, textarea')
        if (input) input.required = true
      } else {
        field.style.display = "none"
        // Remove required when hidden
        const input = field.querySelector('input, select, textarea')
        if (input) {
          input.required = false
          input.value = '' // Clear the value when hiding
        }
      }
    })
  }
}
