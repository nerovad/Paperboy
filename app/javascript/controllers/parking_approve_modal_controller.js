// app/javascript/controllers/parking_approve_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "modal", "form", "select"]
  static values = {
    submissionId: Number,
    approvePath: String,
    employees: Array
  }

  open(event) {
    event.preventDefault()
    
    // Populate the select dropdown with employees
    this.selectTarget.innerHTML = '<option value="">-- Select Employee --</option>'
    
    this.employeesValue.forEach(emp => {
      const option = document.createElement('option')
      option.value = emp.id
      option.textContent = `${emp.name} (${emp.id})`
      this.selectTarget.appendChild(option)
    })
    
    // Set form action
    this.formTarget.action = this.approvePathValue
    
    // Show modal
    this.backdropTarget.style.display = "flex"
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) event.preventDefault()
    this.backdropTarget.style.display = "none"
    document.body.style.overflow = ""
    this.formTarget.reset()
  }

  connect() {
    // Close on backdrop click
    this.backdropTarget.addEventListener('click', (e) => {
      if (e.target === this.backdropTarget) {
        this.close()
      }
    })
  }
}
