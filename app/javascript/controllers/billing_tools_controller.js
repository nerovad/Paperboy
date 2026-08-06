import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="billing-tools"
export default class extends Controller {
  static targets = ["startDate", "endDate", "fiscalPeriod", "form", "submit"]

  connect() {
    this.formTargets.forEach(form => {
      form.addEventListener("submit", () => {
        const s = this.startDateTarget.value;
        const e = this.endDateTarget.value;
        form.querySelector("input[name='s_date']").value = s;
        form.querySelector("input[name='e_date']").value = e;
      });
    });

    const selectedPeriod = this.fiscalPeriodTargets.find(period => period.checked)
    if (selectedPeriod) this.#applyPeriod(selectedPeriod)
  }

  validate(event) {
    this.endDateTarget.setCustomValidity("")

    if (this.startDateTarget.value > this.endDateTarget.value) {
      event.preventDefault()
      this.endDateTarget.setCustomValidity("End date must be on or after start date.")
      this.endDateTarget.reportValidity()
      return
    }

    this.submitTarget.disabled = true
    this.submitTarget.value = "Starting…"
  }

  selectPeriod(event) {
    this.#applyPeriod(event.currentTarget)
  }

  #applyPeriod(period) {
    this.startDateTarget.value = period.dataset.startDate
    this.endDateTarget.value = period.dataset.endDate
    this.endDateTarget.setCustomValidity("")
  }
}
