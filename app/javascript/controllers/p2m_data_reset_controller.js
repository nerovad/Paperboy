import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  async reset() {
    if (!await pbConfirm({
      title: "Reset P2M data",
      message: "Remove all P2M working files and clear the GSABSS processing tables? This cannot be undone.",
      confirmLabel: "Reset Data",
      confirmVariant: "deny"
    })) return

    this.buttonTarget.disabled = true
    const failures = []
    const rows = Array.from(this.element.querySelectorAll("[data-p2m-reset-row]"))

    for (const row of rows) {
      try {
        const response = await this.removeTarget(row.dataset.resetTarget)
        if (!response.ok) {
          failures.push(`${row.dataset.resetTarget}: ${response.message}`)
          continue
        }
        document.getElementById(row.dataset.detailId)?.remove()
        row.remove()
      } catch (_error) {
        failures.push(`${row.dataset.resetTarget}: request failed`)
      }
    }

    if (failures.length) {
      this.buttonTarget.disabled = false
    } else {
      this.buttonTarget.closest(".p2m-batch-actions")?.remove()
    }
    await pbAlert({
      title: failures.length ? "P2M Reset Complete with Errors" : "P2M Reset Complete",
      message: failures.length ? failures.join("; ") : "All P2M reset targets were removed."
    })
  }

  async removeTarget(target) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new URLSearchParams({ target }).toString()
    })
    const result = await response.json()
    return { ok: response.ok, message: result.message || `Reset failed (${response.status}).` }
  }
}
