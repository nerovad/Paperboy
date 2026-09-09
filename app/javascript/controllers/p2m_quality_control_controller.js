import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async toggle(event) {
    const button = event.currentTarget
    const detail = document.getElementById(button.dataset.detailId)
    const expanded = detail.hidden
    detail.hidden = !expanded
    button.setAttribute("aria-expanded", String(expanded))
    if (expanded && !detail.dataset.loaded) {
      const response = await fetch(button.dataset.detailsUrl, { headers: { Accept: "text/html" } })
      detail.querySelector("[data-lazy-details]").innerHTML = response.ok
        ? await response.text()
        : `Quality control details could not be loaded (HTTP ${response.status}).`
      detail.dataset.loaded = "true"
    }
  }
}
