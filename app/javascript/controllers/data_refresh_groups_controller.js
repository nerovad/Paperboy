import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

export default class extends Controller {
  async toggle(event) {
    const detailId = event.currentTarget.dataset.detailId
    const detailRow = document.getElementById(detailId)
    const expanded = detailRow.hidden

    detailRow.hidden = !expanded
    this.element.querySelectorAll(`[data-detail-id="${detailId}"]`).forEach((trigger) => {
      trigger.setAttribute("aria-expanded", String(expanded))
    })
    if (expanded && detailRow.dataset.detailsUrl && detailRow.dataset.loaded !== "true") {
      await this.loadDetails(detailRow)
    }
  }

  async loadDetails(detailRow) {
    const container = detailRow.querySelector("[data-lazy-details]")
    try {
      const response = await fetch(detailRow.dataset.detailsUrl, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(`Details request failed: ${response.status}`)

      container.innerHTML = await response.text()
      detailRow.dataset.loaded = "true"
    } catch (_error) {
      container.textContent = "Associated files could not be loaded."
    }
  }

  async feedback(event) {
    const action = event.currentTarget.dataset.feedbackAction
    const omsNumber = event.currentTarget.dataset.feedbackOms
    await pbAlert({
      title: `${action} pressed`,
      message: `${action} was pressed for OMS ${omsNumber}.`
    })
  }

  async staging(event) {
    const button = event.currentTarget
    const destructive = button.dataset.stagingMethod === "DELETE"
    if (destructive && !await pbConfirm({
      title: button.dataset.stagingAction,
      message: button.dataset.confirmMessage,
      confirmLabel: "Remove",
      confirmVariant: "deny"
    })) return

    const progress = button.dataset.stagingRemoveOnSuccess === "true"
      ? button.closest("[data-controller~='pdf-preview']")?.querySelector("[data-staging-progress]")
      : null
    const startedAt = performance.now()
    const timer = this.startStagingProgress(progress, startedAt)
    button.disabled = true

    const parameters = new URLSearchParams({
      directory: button.dataset.directory,
      oms_number: button.dataset.omsNumber
    })
    try {
      const response = await fetch(button.dataset.stagingUrl, {
        method: button.dataset.stagingMethod,
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: parameters.toString()
      })
      const contentType = response.headers.get("content-type") || ""
      const result = contentType.includes("application/json") ? await response.json() : {}
      const duration = this.elapsedSeconds(startedAt)
      this.stopStagingProgress(progress, timer)
      if (response.ok && button.dataset.stagingRemoveOnSuccess === "true") this.removeOmsRows(button)

      const title = response.ok && button.dataset.stagingRemoveOnSuccess === "true"
        ? `${button.dataset.omsNumber} Moved to Staging`
        : response.ok ? button.dataset.stagingAction : "Staging failed"
      await pbAlert({
        title,
        message: `${result.message || `The staging request failed (${response.status}).`} ` +
          `Elapsed time: ${duration} seconds.`
      })
    } catch (_error) {
      const duration = this.elapsedSeconds(startedAt)
      this.stopStagingProgress(progress, timer)
      await pbAlert({
        title: "Staging failed",
        message: `The staging request could not be completed. Elapsed time: ${duration} seconds.`
      })
    } finally {
      button.disabled = false
    }
  }

  startStagingProgress(progress, startedAt) {
    if (!progress) return null

    const label = progress.querySelector("[data-staging-progress-label]")
    const update = () => {
      label.textContent = `Moving files… ${this.elapsedSeconds(startedAt)} seconds elapsed`
    }
    progress.hidden = false
    update()
    return window.setInterval(update, 100)
  }

  stopStagingProgress(progress, timer) {
    if (timer) window.clearInterval(timer)
    if (progress) progress.hidden = true
  }

  elapsedSeconds(startedAt) {
    return ((performance.now() - startedAt) / 1000).toFixed(1)
  }

  removeOmsRows(button) {
    const detailRow = button.closest("tr.p2m-maildat-detail")
    const resultRow = detailRow?.previousElementSibling
    if (resultRow?.matches("tr.p2m-maildat-row")) resultRow.remove()
    detailRow?.remove()
    this.element.querySelectorAll("tr[data-sort-row]").forEach((row, index) => {
      row.classList.toggle("is-alternate", index % 2 === 1)
    })
  }
}
