import { Controller } from "@hotwired/stimulus"

// The visibility choices on the Publish form belong to whichever target is
// selected: "unlisted" is a YouTube word, "SELF_ONLY" a TikTok one, and a
// custom endpoint has no opinion at all. This swaps them as the target
// changes, and hides the field entirely when the target offers none.
export default class extends Controller {
  static targets = ["target", "privacy", "privacyGroup"]
  static values = { privacies: Object }

  connect() {
    this.refresh()
  }

  refresh() {
    const options = this.privaciesValue[this.targetTarget.value] || {}
    const keys = Object.keys(options)
    this.privacyGroupTarget.hidden = keys.length === 0
    this.privacyTarget.replaceChildren()
    keys.forEach((key) => this.privacyTarget.appendChild(new Option(options[key], key)))
  }
}
