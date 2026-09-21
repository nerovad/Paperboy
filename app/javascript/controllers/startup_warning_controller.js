import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

const SHOWN_KEY = "paperboy-startup-warnings-shown"

export default class extends Controller {
  connect() {
    if (sessionStorage.getItem(SHOWN_KEY)) return

    const warnings = JSON.parse(this.element.dataset.startupWarnings || "[]")
    if (!warnings.length) return

    sessionStorage.setItem(SHOWN_KEY, "true")
    void pbAlert({
      title: "Paperboy startup warning",
      message: "The following configuration is missing or unreachable:",
      warnings,
      buttonLabel: "Continue"
    })
  }
}
