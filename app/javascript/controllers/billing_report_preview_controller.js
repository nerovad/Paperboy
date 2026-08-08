import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "title", "body"]

  connect() {
    this.keydown = this.keydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
  }

  async open(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.previouslyFocused = button
    this.titleTarget.textContent = button.dataset.previewTitle || "Billing Report"
    this.bodyTarget.replaceChildren(this.loadingMessage())
    this.backdropTarget.hidden = false
    document.addEventListener("keydown", this.keydown)
    this.backdropTarget.querySelector(".pb-modal__close")?.focus()

    if (button.dataset.previewKind === "pdf") {
      this.showPdf(button.dataset.previewUrl)
    } else {
      await this.showSpreadsheet(button.dataset.previewUrl)
    }
  }

  close() {
    this.backdropTarget.hidden = true
    this.bodyTarget.replaceChildren()
    document.removeEventListener("keydown", this.keydown)
    this.previouslyFocused?.focus()
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) this.close()
  }

  keydown(event) {
    if (event.key !== "Escape") return

    event.preventDefault()
    this.close()
  }

  showPdf(url) {
    const frame = document.createElement("iframe")
    frame.className = "billing-report-preview__pdf"
    frame.title = this.titleTarget.textContent
    frame.src = url
    this.bodyTarget.replaceChildren(frame)
  }

  async showSpreadsheet(url) {
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(`Preview failed with status ${response.status}`)

      this.bodyTarget.innerHTML = await response.text()
    } catch (_error) {
      const message = document.createElement("p")
      message.className = "dashboard-error"
      message.textContent = "The Billing report could not be displayed."
      this.bodyTarget.replaceChildren(message)
    }
  }

  loadingMessage() {
    const message = document.createElement("p")
    message.textContent = "Loading report…"
    return message
  }
}
