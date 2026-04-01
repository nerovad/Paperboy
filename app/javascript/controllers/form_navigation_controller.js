import { Controller } from "@hotwired/stimulus"

// Unified multi-page form navigation controller.
// Handles page show/hide, Next/Prev/Submit button visibility,
// progress dots, and page-by-page validation on Next.
export default class extends Controller {
  static targets = ["submitButton"]

  connect() {
    this.form = this.element.querySelector("form") || this.element.closest("form")
    this.pages = Array.from(this.element.querySelectorAll(".form-page"))
    this.nextBtn = this.element.querySelector("#nextBtn")
    this.prevBtn = this.element.querySelector("#prevBtn")
    this.dots = Array.from(this.element.querySelectorAll(".progress-dots .dot"))

    if (this.pages.length === 0) return

    // Disable native validation — we validate page-by-page on Next clicks.
    // Without this, the browser tries to validate hidden fields (e.g. Choices.js
    // selects) and silently blocks submission when it can't show a popup.
    if (this.form) this.form.setAttribute("novalidate", "")

    this.current = 0
    this.showCurrentPage()
  }

  showCurrentPage() {
    this.pages.forEach((page, i) => {
      page.style.display = i === this.current ? "" : "none"
    })

    const onLastPage = this.current === this.pages.length - 1
    const onFirstPage = this.current === 0

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.style.display = onLastPage ? "inline-block" : "none"
    }

    if (this.nextBtn) {
      this.nextBtn.style.display = onLastPage ? "none" : "inline-block"
    }

    if (this.prevBtn) {
      this.prevBtn.style.display = onFirstPage ? "none" : "inline-block"
    }

    this.dots.forEach((dot, i) => {
      dot.classList.toggle("active", i === this.current)
    })
  }

  // Validate visible, enabled fields on the current page.
  // Skips fields inside Choices.js containers (hidden originals).
  validateCurrentPage() {
    const page = this.pages[this.current]
    const fields = page.querySelectorAll("input, select, textarea")
    for (const field of fields) {
      if (field.disabled) continue
      if (field.closest(".choices")) continue
      if (!field.checkValidity()) {
        field.reportValidity()
        return false
      }
    }
    return true
  }

  nextPage() {
    if (this.current < this.pages.length - 1) {
      if (!this.validateCurrentPage()) return
      this.current++
      this.showCurrentPage()
    }
  }

  prevPage() {
    if (this.current > 0) {
      this.current--
      this.showCurrentPage()
    }
  }
}
