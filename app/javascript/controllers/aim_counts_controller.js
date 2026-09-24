import { Controller } from "@hotwired/stimulus"

// Fill in AIM's queue counts after the page has drawn, so no screen waits on
// them. Every element inside with data-aim-count="<queue>" (or "my_queue")
// gets its number from /aim/counts; a count that cannot be read stays "–".
export default class extends Controller {
  static values = { url: String }

  // The last counts seen are shown at once, then refreshed in place, so
  // moving between pages does not blink the badges.
  async connect() {
    this.show(this.remembered())
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const counts = await response.json()
      this.show(counts)
      this.remember(counts)
    } catch (error) {
      console.warn("AIM counts could not be loaded", error)
    }
  }

  show(counts) {
    if (!counts) return
    this.fill("my_queue", counts.my_queue)
    this.fill("shared_queues", counts.shared_queues)
    Object.entries(counts.queues || {}).forEach(([queue, count]) => this.fill(queue, count))
  }

  remembered() {
    try {
      return JSON.parse(sessionStorage.getItem("aim-counts") || "null")
    } catch {
      return null
    }
  }

  remember(counts) {
    try {
      sessionStorage.setItem("aim-counts", JSON.stringify(counts))
    } catch {
      // Storage refused: the counts still load, just without the head start.
    }
  }

  fill(key, count) {
    this.element.querySelectorAll(`[data-aim-count="${key}"]`).forEach((element) => {
      element.textContent = count ?? "–"
      element.hidden = element.dataset.hideZero !== undefined && !count
    })
  }
}
