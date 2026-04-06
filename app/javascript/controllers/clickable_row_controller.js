import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  click(event) {
    // Don't navigate if clicking a link or button inside the row
    if (event.target.closest("a, button")) return

    const url = event.currentTarget.dataset.href
    if (url) window.location.href = url
  }
}
