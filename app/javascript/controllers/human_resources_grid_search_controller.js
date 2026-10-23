import { Controller } from "@hotwired/stimulus"

// Wait the same 250 ms Chart of Accounts and AIM person search wait, then
// submit the grid search. The form targets the grid frame, so the field
// keeps focus while the page underneath is replaced.
export default class extends Controller {
  static values = { debounce: { type: Number, default: 250 } }

  disconnect() {
    this.cancel()
  }

  schedule() {
    this.cancel()
    this.timer = setTimeout(() => this.element.requestSubmit(), this.debounceValue)
  }

  cancel() {
    clearTimeout(this.timer)
  }
}
