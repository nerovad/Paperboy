// app/javascript/controllers/command_palette_controller.js
//
// The command palette: ":" from anywhere that is not a text box.
//
// The palette owns the keyboard and nothing else. What it lists, ranks and
// highlights is sidebar_search_controller working inside the frame — the same
// search the Paperboy sidebar runs, over the same catalog — so there is one
// matching rule in the app and the palette only decides what the keys mean.
//
// The one rule that makes ":" safe to take: a keystroke aimed at a field is
// never ours. Somebody typing a colon into a form gets a colon.
import { Controller } from "@hotwired/stimulus"

// Where a keystroke belongs to what the person is typing, not to the app.
const TYPING_TAGS = ["INPUT", "TEXTAREA", "SELECT"]

export default class extends Controller {
  static targets = ["modal", "input"]

  connect() {
    this.cursor = 0
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.body.style.overflow = ""
  }

  onKeydown(event) {
    if (this.isOpen && event.key === "Escape") {
      this.close()
      return
    }

    if (event.key !== ":" || event.metaKey) return
    if (this.typing(event.target) || this.otherDialogOpen()) return

    event.preventDefault()
    this.open()
  }

  // A colon typed into a field is a colon. Shift is expected — ":" is a
  // shifted key on most layouts — and AltGr (which arrives as ctrl+alt) is how
  // several others reach it, so neither disqualifies the keystroke.
  typing(element) {
    if (!element) return false

    return element.isContentEditable || TYPING_TAGS.includes(element.tagName)
  }

  // A dialog already has the person's attention, and its own Escape handler.
  // Opening the palette over the top of one would leave two things listening.
  otherDialogOpen() {
    return [...document.querySelectorAll(".pb-modal-backdrop:not([hidden])")]
      .some(backdrop => backdrop !== this.modalTarget)
  }

  get isOpen() {
    return !this.modalTarget.hidden
  }

  open() {
    this.modalTarget.hidden = false
    document.body.style.overflow = "hidden"
    // Nothing on the first press: the frame is lazy and starts loading now.
    // focusInput runs again on turbo:frame-load, which is when it lands.
    this.focusInput()
  }

  close() {
    this.modalTarget.hidden = true
    document.body.style.overflow = ""
  }

  // Only a click on the backdrop itself dismisses; clicks that bubble up from
  // the dialog do not.
  backdropClose(event) {
    if (event.target === this.modalTarget) this.close()
  }

  // Every open starts clean: an old query still on screen reads as results that
  // failed to update. The input event puts sidebar-search back to its full
  // list without this controller knowing how that list is built.
  focusInput() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.focus()
  }

  next(event) {
    this.moveCursor(event, 1)
  }

  previous(event) {
    this.moveCursor(event, -1)
  }

  resetCursor() {
    this.cursor = 0
    this.markCursor()
  }

  // Enter takes whatever the cursor is on, which with no arrow pressed is the
  // top result — the one sidebar-search ranked first.
  activate(event) {
    const results = this.results()
    if (!results.length) return

    event.preventDefault()
    results[Math.min(this.cursor, results.length - 1)].click()
  }

  moveCursor(event, step) {
    const results = this.results()
    if (!results.length) return

    event.preventDefault()
    this.cursor = (this.cursor + step + results.length) % results.length
    this.markCursor()
  }

  markCursor() {
    const results = this.results()

    results.forEach((result, index) => {
      const current = index === this.cursor
      result.classList.toggle("is-cursor", current)
      if (current) result.scrollIntoView({ block: "nearest" })
    })
  }

  // Read from the DOM every time rather than cached: sidebar-search reorders
  // and re-hides these rows on each keystroke, so any list kept from the last
  // one is already wrong.
  results() {
    const rows = this.element.querySelectorAll(
      "[data-sidebar-search-target='command'], [data-sidebar-search-target='formLink']"
    )

    return [...rows].filter(row => !row.hidden && row.style.display !== "none")
  }
}
