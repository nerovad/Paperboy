import { Controller } from "@hotwired/stimulus"

// The review page's notices (#160) are chips in its header. A chip drops its
// notice's panel down over the page -- the PDF and the fields keep their
// height -- and only one is open at a time. A click outside the open panel
// and its chip, or Escape, closes it. A dialog opened from a panel (the
// Replacement prompt, a Restore reason) lives inside that panel, so working
// in it leaves the panel open.
export default class extends Controller {
  static targets = ["chip", "panel"]

  connect() {
    this.onClick = (event) => {
      if (!this.openPanel || this.openPanel.contains(event.target)) return
      if (this.chipTargets.some((chip) => chip.contains(event.target))) return
      if (event.target.closest(".pb-modal-backdrop")) return
      this.close()
    }
    this.onKey = (event) => {
      if (event.key !== "Escape" || !this.openPanel) return
      if (this.openPanel.querySelector(".pb-modal-backdrop:not([hidden])")) return
      this.close()
    }
    this.onBlur = () => setTimeout(() => {
      if (this.openPanel && document.activeElement?.tagName === "IFRAME") this.close()
    }, 0)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKey)
    window.addEventListener("blur", this.onBlur)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKey)
    window.removeEventListener("blur", this.onBlur)
  }

  toggle(event) {
    const chip = event.currentTarget
    const panel = this.panelTargets.find((p) => p.id === chip.getAttribute("aria-controls"))
    const opening = panel && panel !== this.openPanel
    this.close()
    if (!opening) return

    panel.hidden = false
    chip.setAttribute("aria-expanded", "true")
    this.openPanel = panel
  }

  close() {
    this.panelTargets.forEach((panel) => { panel.hidden = true })
    this.chipTargets.forEach((chip) => chip.setAttribute("aria-expanded", "false"))
    this.openPanel = null
  }
}
