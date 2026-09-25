import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "progress"]

  disconnect() {
    this.stopProgress()
  }

  connect() {
    this.validateRange()
  }

  submit(event) {
    this.validateRange()
    if (this.startDateTarget.value > this.endDateTarget.value) {
      event.preventDefault()
      this.endDateTarget.reportValidity()
      return
    }

    event.preventDefault()
    this.startProgress()
    this.searchToken = window.crypto?.randomUUID?.() ||
      `${Date.now()}-${Math.random().toString(36).slice(2)}`
    this.abortController = new AbortController()
    this.search(event.currentTarget)
  }

  async search(form) {
    const method = form.method.toUpperCase()
    const values = new URLSearchParams(new FormData(form))
    values.set("search_token", this.searchToken)
    const url = method === "GET" ? `${form.action}?${values}` : form.action
    const options = {
      method,
      credentials: "same-origin",
      signal: this.abortController.signal,
      headers: { Accept: "text/html" }
    }
    if (method !== "GET") {
      options.body = values
      options.headers["X-CSRF-Token"] = document.querySelector("meta[name='csrf-token']")?.content
    }

    try {
      const response = await fetch(url, options)
      if (!response.ok) throw new Error(`Search failed: ${response.status}`)

      const html = await response.text()
      const next = new DOMParser().parseFromString(html, "text/html")
      document.title = next.title
      history.replaceState({}, "", response.url)
      document.body.replaceWith(next.body)
    } catch (error) {
      if (error.name !== "AbortError") {
        this.stopProgress()
        await this.showSearchError()
      }
    }
  }

  cancel(event) {
    this.cancelSearch()
    this.abortSearch()
  }

  validateRange() {
    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value
    const invalid = startDate && endDate && startDate > endDate

    this.startDateTarget.max = endDate
    this.endDateTarget.min = startDate
    this.endDateTarget.setCustomValidity(invalid ? "End date must be on or after start date." : "")
  }

  reset() {
    this.cancelSearch()
    this.abortSearch()
    this.stopProgress()
    requestAnimationFrame(() => this.validateRange())
  }

  abortSearch() {
    this.abortController?.abort()
    this.abortController = null
  }

  cancelSearch() {
    if (!this.searchToken) return

    fetch(this.element.dataset.dateRangeCancelUrl, {
      method: "POST",
      credentials: "same-origin",
      keepalive: true,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new URLSearchParams({ token: this.searchToken }).toString()
    })
    this.searchToken = null
  }

  async showSearchError() {
    const message = document.createElement("p")
    message.className = "p2m-date-range-error"
    message.textContent = "The search could not be completed. Please try again."
    this.progressTarget.replaceWith(message)
  }

  startProgress() {
    if (!this.hasProgressTarget) return

    this.progressTarget.hidden = false
    this.progressStartedAt = performance.now()
    this.updateProgress()
    this.progressTimer = window.setInterval(() => this.updateProgress(), 100)
  }

  updateProgress() {
    if (!this.hasProgressTarget) return

    const elapsed = ((performance.now() - this.progressStartedAt) / 1000).toFixed(1)
    this.progressTarget.querySelector("[data-date-range-progress-label]").textContent =
      `Finding files… ${elapsed} seconds elapsed`
  }

  stopProgress() {
    if (this.progressTimer) window.clearInterval(this.progressTimer)
    this.progressTimer = null
    if (this.hasProgressTarget) this.progressTarget.hidden = true
  }
}
