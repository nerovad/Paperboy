import { Controller } from "@hotwired/stimulus"

// A possible duplicate's Replacement (#160): asks where the replacement goes
// -- the original's queue, or one picked -- before posting the invoice form.
// The fields live on the banner, outside that form, and submit with it by
// their form attribute; "Another queue" shows the person picker.
export default class extends Controller {
  static targets = ["backdrop", "other", "picker"]

  connect() {
    this.onKey = (event) => { if (event.key === "Escape" && this.hasBackdropTarget && !this.backdropTarget.hidden) this.close() }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  open() {
    this.backdropTarget.hidden = false
  }

  close() {
    this.backdropTarget.hidden = true
  }

  pick() {
    this.pickerTarget.hidden = !this.otherTarget.checked
  }
}
