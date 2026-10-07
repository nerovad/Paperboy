import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

export default class extends Controller {
  static targets = ["button", "progress"]
  static values = { url: String }

  async archive() {
    if (!await pbConfirm({
      title: "Archive historical jobs",
      message: "Move the listed OMS files from 7/1/2026 through 9/30/2026 into Processed?",
      confirmLabel: "Archive",
      confirmVariant: "approve"
    })) return

    this.buttonTarget.disabled = true
    const failures = []
    const rows = Array.from(this.element.querySelectorAll("[data-p2m-archive-row]"))
    this.startedAt = performance.now()
    this.completed = 0
    this.total = rows.length
    const timer = this.startProgress()

    try {
      for (const row of rows) {
        try {
          const response = await this.moveOms(row.dataset.omsNumber)
          if (!response.ok) {
            failures.push(response.message)
            continue
          }
          document.getElementById(row.dataset.detailId)?.remove()
          row.remove()
        } catch (_error) {
          failures.push(`${row.dataset.omsNumber}: request failed`)
        } finally {
          this.completed += 1
          this.updateProgress()
        }
      }
    } finally {
      window.clearInterval(timer)
      this.progressTarget.hidden = true
    }

    if (failures.length) {
      this.buttonTarget.disabled = false
    } else {
      this.buttonTarget.closest(".p2m-batch-actions")?.remove()
    }
    await pbAlert({
      title: failures.length ? "Archive finished with jobs stopped" : "Archive complete",
      message: failures.length ? failures.join("; ") : "The listed historical jobs were archived."
    })
  }

  startProgress() {
    this.progressTarget.hidden = false
    this.updateProgress()
    return window.setInterval(() => this.updateProgress(), 100)
  }

  updateProgress() {
    const elapsed = ((performance.now() - this.startedAt) / 1000).toFixed(1)
    const bar = this.progressTarget.querySelector("[data-archive-progress-bar]")
    bar.max = this.total || 1
    bar.value = this.completed
    this.progressTarget.querySelector("[data-archive-progress-label]").textContent =
      `${this.completed} of ${this.total} jobs archived · ${elapsed} seconds elapsed`
  }

  async moveOms(omsNumber) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new URLSearchParams({ oms_number: omsNumber }).toString()
    })
    const result = await response.json().catch(() => ({}))
    return { ok: response.ok, message: result.message || `Archive failed (${response.status}).` }
  }
}
