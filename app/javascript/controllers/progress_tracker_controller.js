import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { url: String }

  connect() {
    this.poll()
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  async poll() {
    const status = this.contentTarget.querySelector("[data-progress-status]")?.dataset.progressStatus
    if (["succeeded", "failed"].includes(status)) return

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      if (response.ok) this.contentTarget.innerHTML = await response.text()
    } finally {
      this.timer = window.setTimeout(() => this.poll(), 2000)
    }
  }
}
