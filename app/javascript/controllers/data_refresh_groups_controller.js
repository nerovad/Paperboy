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
      await pbAlert({
        title: response.ok ? button.dataset.stagingAction : "Staging failed",
        message: result.message || `The staging request failed (${response.status}).`
      })
    } catch (_error) {
      await pbAlert({
        title: "Staging failed",
        message: "The staging request could not be completed."
      })
    }
  }
}
