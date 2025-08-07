import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="billing-tools"
export default class extends Controller {
  static targets = ["startDate", "endDate", "form"]

  connect() {
    this.formTargets.forEach(form => {
      form.addEventListener("submit", () => {
        const s = this.startDateTarget.value;
        const e = this.endDateTarget.value;
        form.querySelector("input[name='s_date']").value = s;
        form.querySelector("input[name='e_date']").value = e;
      });
    });
  }
}
