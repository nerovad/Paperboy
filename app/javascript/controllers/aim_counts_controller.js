import { Controller } from "@hotwired/stimulus"

// Fill in AIM's queue counts after the page has drawn, so no screen waits on
// them. Every element inside with data-aim-count="<queue>" (or "my_queue")
// gets its number from /aim/counts; a count that cannot be read stays "–".
export default class extends Controller {
  static values = { url: String }

  async connect() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const counts = await response.json()
      this.fill("my_queue", counts.my_queue)
      Object.entries(counts.queues || {}).forEach(([queue, count]) => this.fill(queue, count))
    } catch (error) {
      console.warn("AIM counts could not be loaded", error)
    }
  }

  fill(key, count) {
    this.element.querySelectorAll(`[data-aim-count="${key}"]`).forEach((element) => {
      element.textContent = count ?? "–"
      element.hidden = element.dataset.hideZero !== undefined && !count
    })
  }
}
