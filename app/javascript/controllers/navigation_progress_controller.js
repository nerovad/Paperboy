import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  start() {
    if (this.progress) return

    this.startedAt = performance.now()
    this.progress = document.createElement("div")
    this.progress.className = "p2m-navigation-progress"
    this.progress.setAttribute("role", "status")
    this.progress.setAttribute("aria-live", "polite")
    this.progress.innerHTML = '<progress max="1" value="0" aria-label="Loading Data Reset"></progress>' +
      '<span>Loading Data Reset… 0.0 seconds elapsed</span>'
    document.body.appendChild(this.progress)
    this.timer = window.setInterval(() => this.update(), 100)
    this.update()
  }

  update() {
    if (!this.progress) return

    const elapsed = ((performance.now() - this.startedAt) / 1000).toFixed(1)
    this.progress.querySelector("span").textContent =
      `Loading Data Reset… ${elapsed} seconds elapsed`
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
    this.progress?.remove()
  }
}
