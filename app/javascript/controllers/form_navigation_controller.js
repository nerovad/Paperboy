import { Controller } from "@hotwired/stimulus"

// Unified multi-page form navigation controller.
// Handles page show/hide, Next/Prev/Submit button visibility, and page-by-page
// validation. The progress dots double as controls: clicking (or focusing and
// pressing Enter/arrow keys) jumps to that page.
export default class extends Controller {
  static targets = ["submitButton", "errorSummary"]

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

    this.prepareDots()

    // After a failed submit the server re-renders the form. Open the first page
    // that contains an errored field (Rails wraps these in .field_with_errors)
    // instead of silently dropping the user back on page 1.
    this.current = this.firstErroredPage()
    this.showCurrentPage()

    if (this.hasErrorSummaryTarget) {
      this.errorSummaryTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  disconnect() {
    this.dotListeners?.forEach(({ dot, click, keydown }) => {
      dot.removeEventListener("click", click)
      dot.removeEventListener("keydown", keydown)
    })
    this.dotListeners = null
  }

  // Turn the plain progress dots into real, keyboard-reachable controls.
  // Wiring happens here rather than in markup because the dots are emitted from
  // three places (hand-written views, the form builder's regen, and the
  // generator templates) — doing it in JS keeps all three in sync for free.
  prepareDots() {
    this.dotListeners = []

    this.dots.forEach((dot, index) => {
      const page = this.pages[index]
      if (!page) return

      const title = this.pageTitle(index)
      dot.setAttribute("role", "button")
      dot.setAttribute("tabindex", "0")
      // data-tooltip drives a CSS tooltip, not the native `title` attribute —
      // browsers hard-code a ~1s delay on `title` and the OS paints it, so
      // neither the timing nor the styling can be controlled.
      dot.dataset.tooltip = title || `Page ${index + 1}`
      dot.setAttribute("aria-label", `Go to page ${index + 1}${title ? `: ${title}` : ""}`)

      // Server-side validation errors on a page the user isn't looking at.
      if (page.querySelector(".field_with_errors")) dot.classList.add("has-error")

      const click = () => this.goToPage(index)
      const keydown = event => this.onDotKeydown(event, index)
      dot.addEventListener("click", click)
      dot.addEventListener("keydown", keydown)
      this.dotListeners.push({ dot, click, keydown })
    })
  }

  // Generated pages open with an <h2> naming the section — reuse it so hovering
  // a dot says "Physician Information" rather than "Page 4". Null when a page
  // has no heading.
  pageTitle(index) {
    const heading = this.pages[index].querySelector("h2")
    return heading?.textContent?.trim() || null
  }

  // Arrow keys move between pages while a dot has focus; Enter/Space activate.
  // Scoped to the dots so it never hijacks arrow keys inside a text field.
  onDotKeydown(event, index) {
    let target = null

    switch (event.key) {
      case "Enter":
      case " ":
        target = index
        break
      case "ArrowLeft":
      case "ArrowUp":
        target = this.current - 1
        break
      case "ArrowRight":
      case "ArrowDown":
        target = this.current + 1
        break
      default:
        return
    }

    event.preventDefault()
    if (target < 0 || target >= this.pages.length) return
    this.goToPage(target)
    this.dots[this.current]?.focus()
  }

  // Jump straight to a page. Going back is always free; going forward validates
  // every page it would skip, so the dots can't be used to bypass the same
  // checks Next enforces. A failure lands the user on the offending page.
  goToPage(index) {
    if (index === this.current) return

    if (index > this.current) {
      for (let i = this.current; i < index; i++) {
        const field = this.invalidFieldOn(i)
        if (!field) continue

        this.current = i
        this.showCurrentPage()
        field.reportValidity()
        return
      }
    }

    this.current = index
    this.showCurrentPage()
  }

  // Index of the first page containing a validation error, or 0 if none.
  firstErroredPage() {
    const idx = this.pages.findIndex(page => page.querySelector(".field_with_errors"))
    return idx >= 0 ? idx : 0
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
      const active = i === this.current
      dot.classList.toggle("active", active)
      // Pages the user has already moved past, so the dots read as progress.
      if (i < this.current) dot.classList.add("visited")
      if (active) {
        dot.setAttribute("aria-current", "step")
      } else {
        dot.removeAttribute("aria-current")
      }
    })
  }

  // First invalid field on a page, or null. Skips fields inside Choices.js
  // containers (hidden originals) since the browser can't surface those.
  invalidFieldOn(index) {
    const page = this.pages[index]
    if (!page) return null

    for (const field of page.querySelectorAll("input, select, textarea")) {
      if (field.disabled) continue
      if (field.closest(".choices")) continue
      if (!field.checkValidity()) return field
    }
    return null
  }

  nextPage() {
    if (this.current < this.pages.length - 1) this.goToPage(this.current + 1)
  }

  prevPage() {
    if (this.current > 0) this.goToPage(this.current - 1)
  }
}
