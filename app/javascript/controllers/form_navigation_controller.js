import { Controller } from "@hotwired/stimulus"

// Room the chapter rail needs in the margin beside the card: its 200px width,
// the 28px gap, and a little slack. Keep in step with _forms.scss.
const RAIL_MIN_ROOM = 232

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
    this.buildRail()

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

    this.railObserver?.disconnect()
    this.railObserver = null
    this.railHost = null

    // Listeners go with it, since the whole subtree is discarded.
    this.rail?.remove()
    this.rail = null
    this.railItems = null
  }

  // Build the chapter rail: the page headings listed vertically beside the card.
  // Injected here rather than added to markup so it needs no changes to the
  // views, the form builder's regen, or the generator templates.
  buildRail() {
    // A Turbo snapshot can be cached with the rail already in it, so clear any
    // previous one instead of stacking a second.
    this.element.querySelector(".chapter-rail")?.remove()
    this.railItems = []
    this.rail = null

    if (this.pages.length < 2) return

    const nav = document.createElement("nav")
    nav.className = "chapter-rail"
    nav.setAttribute("aria-label", "Form sections")

    const inner = document.createElement("div")
    inner.className = "chapter-rail__inner"

    const heading = document.createElement("p")
    heading.className = "chapter-rail__title"
    heading.textContent = "Sections"

    const list = document.createElement("ol")

    this.pages.forEach((page, index) => {
      const item = document.createElement("li")
      item.className = "chapter-rail__item"
      if (page.querySelector(".field_with_errors")) item.classList.add("is-error")

      const button = document.createElement("button")
      button.type = "button"
      button.className = "chapter-rail__link"

      const number = document.createElement("span")
      number.className = "chapter-rail__num"
      number.textContent = index + 1
      number.setAttribute("aria-hidden", "true")

      const name = document.createElement("span")
      name.className = "chapter-rail__name"
      // textContent, not innerHTML — the heading is arbitrary author-entered
      // text coming back out of the DOM.
      name.textContent = this.pageTitle(index) || `Page ${index + 1}`

      button.append(number, name)
      button.addEventListener("click", () => this.goToPage(index))
      button.addEventListener("keydown", event => this.onRailKeydown(event))

      item.appendChild(button)
      list.appendChild(item)
      this.railItems.push(item)
    })

    inner.append(heading, list)
    nav.appendChild(inner)

    // Prepended so keyboard tab order matches the rail's visual position
    // ahead of the form rather than trailing every field on the page.
    this.element.prepend(nav)
    this.rail = nav

    // The content area, not the window, is what the rail has to fit inside.
    this.railHost = this.element.closest("#main-content") || document.body
    this.railObserver = new ResizeObserver(() => this.fitRail())
    this.railObserver.observe(this.railHost)
  }

  // The rail lives in the margin beside the centred card, so it may only appear
  // when that margin is genuinely wide enough. Measured rather than set with a
  // media query because the sidebar (280px open, 42px collapsed) changes how
  // much room is left over at any given viewport width — a query on viewport
  // width would show the rail when it doesn't fit and scroll the page sideways.
  fitRail() {
    if (!this.rail) return

    const room = this.element.getBoundingClientRect().left -
      this.railHost.getBoundingClientRect().left
    this.rail.classList.toggle("is-cramped", room < RAIL_MIN_ROOM)
  }

  // Up/Down (and Left/Right) step through chapters while the rail has focus,
  // mirroring the dots. Bound to the buttons so it never steals arrow keys
  // from a text field.
  onRailKeydown(event) {
    let target

    switch (event.key) {
      case "ArrowUp":
      case "ArrowLeft":
        target = this.current - 1
        break
      case "ArrowDown":
      case "ArrowRight":
        target = this.current + 1
        break
      default:
        return
    }

    event.preventDefault()
    if (target < 0 || target >= this.pages.length) return
    this.goToPage(target)
    this.railItems[this.current]?.querySelector("button")?.focus()
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

    this.railItems?.forEach((item, i) => {
      const active = i === this.current
      item.classList.toggle("is-current", active)
      if (i < this.current) item.classList.add("is-done")

      const link = item.querySelector(".chapter-rail__link")
      if (active) {
        link.setAttribute("aria-current", "step")
      } else {
        link.removeAttribute("aria-current")
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
