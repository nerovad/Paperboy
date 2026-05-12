// app/javascript/controllers/dashboards_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["formSelect", "container", "iframe"]

  loadDashboard(event) {
    event.target.form.requestSubmit()
  }
}
