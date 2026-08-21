import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

export default class extends Controller {
  toggle(event) {
    const detailId = event.currentTarget.dataset.detailId
    const detailRow = document.getElementById(detailId)
    const expanded = detailRow.hidden

    detailRow.hidden = !expanded
    this.element.querySelectorAll(`[data-detail-id="${detailId}"]`).forEach((trigger) => {
      trigger.setAttribute("aria-expanded", String(expanded))
    })
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
