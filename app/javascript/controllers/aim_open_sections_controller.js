import { Controller } from "@hotwired/stimulus"

// Collapsible <details> sections that stay as they were after a button on the
// page (#131): opening or closing one writes the open ones to the address
// (?open=2551,2553), which the server reads to draw them open again. A
// button's redirect goes back to that address, so nothing snaps shut.
export default class extends Controller {
  static targets = ["section"]

  toggled() {
    const open = this.sectionTargets.filter((section) => section.open).map((section) => section.dataset.key)
    const url = new URL(window.location.href)
    if (open.length) url.searchParams.set("open", open.join(","))
    else url.searchParams.delete("open")
    history.replaceState(history.state, "", url)
  }
}
