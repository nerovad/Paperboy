import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "title", "body"]

  connect() {
    this.keydown = this.keydown.bind(this)
  }

  disconnect() {
    this.stopLoadingProgress()
    document.removeEventListener("keydown", this.keydown)
  }

  open(event) {
    event.preventDefault()
    const link = event.currentTarget
    this.previouslyFocused = link
    this.titleTarget.textContent = link.dataset.pdfPreviewTitle || "PDF Preview"

    const frame = document.createElement("iframe")
    frame.className = "pb-pdf-preview__frame"
    frame.title = this.titleTarget.textContent
    const progress = document.createElement("div")
    progress.className = "pb-pdf-preview__progress"
    progress.innerHTML = '<progress max="1" value="0" aria-label="Loading PDF"></progress>' +
      '<span aria-live="polite">Loading PDF… 0.0 seconds elapsed</span>'
    const startedAt = performance.now()
    this.loadingTimer = window.setInterval(() => {
      const elapsed = ((performance.now() - startedAt) / 1000).toFixed(1)
      progress.querySelector("span").textContent = `Loading PDF… ${elapsed} seconds elapsed`
    }, 100)
    frame.addEventListener("load", () => {
      this.stopLoadingProgress()
      progress.hidden = true
    }, { once: true })
    frame.src = link.href
    this.bodyTarget.replaceChildren(progress, frame)

    this.backdropTarget.hidden = false
    document.addEventListener("keydown", this.keydown)
    this.backdropTarget.querySelector(".pb-modal__close")?.focus()
  }

  close() {
    this.stopLoadingProgress()
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

  stopLoadingProgress() {
    if (this.loadingTimer) window.clearInterval(this.loadingTimer)
    this.loadingTimer = null
  }
}
