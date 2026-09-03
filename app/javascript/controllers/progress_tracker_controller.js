import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { url: String }

  connect() {
    this.updateElapsedTimes()
    this.clock = window.setInterval(() => this.updateElapsedTimes(), 100)
    this.poll()
  }

  disconnect() {
    window.clearTimeout(this.timer)
    window.clearInterval(this.clock)
  }

  async poll() {
    const status = this.contentTarget.querySelector("[data-progress-status]")?.dataset.progressStatus
    if (["succeeded", "failed"].includes(status)) {
      window.clearInterval(this.clock)
      return
    }

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      if (response.ok) this.contentTarget.innerHTML = await response.text()
    } finally {
      this.timer = window.setTimeout(() => this.poll(), 2000)
    }
  }

  updateElapsedTimes() {
    this.contentTarget.querySelectorAll("[data-progress-elapsed][data-started-at]").forEach(element => {
      const startedAt = Date.parse(element.dataset.startedAt)
      if (Number.isNaN(startedAt)) return

      element.textContent = this.formatDuration((Date.now() - startedAt) / 1000)
    })
  }

  formatDuration(seconds) {
    if (seconds >= 3600) {
      return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m ${Math.floor(seconds % 60)}s`
    }
    if (seconds >= 60) return `${Math.floor(seconds / 60)}m ${Math.floor(seconds % 60)}s`
    return `${seconds.toFixed(1)}s`
  }
}
