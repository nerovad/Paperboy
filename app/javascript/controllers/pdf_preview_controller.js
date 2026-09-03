import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "title", "body"]

  connect() {
    this.keydown = this.keydown.bind(this)
  }

  disconnect() {
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
    frame.src = link.href
    this.bodyTarget.replaceChildren(frame)

    this.backdropTarget.hidden = false
    document.addEventListener("keydown", this.keydown)
    this.backdropTarget.querySelector(".pb-modal__close")?.focus()
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
}
