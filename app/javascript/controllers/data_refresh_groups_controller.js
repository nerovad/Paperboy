import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

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
}
