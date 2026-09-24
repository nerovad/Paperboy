import { Controller } from "@hotwired/stimulus"

// A drop area for the AIM upload form. Files dropped on it land in the real
// <input type="file">, so the form submits exactly as if they were chosen
// with the button; nothing is uploaded until Upload is pressed.
//
//   <div data-controller="aim-dropzone">
//     <div data-aim-dropzone-target="zone" data-action="dragover->aim-dropzone#over ...">
//     <input type="file" multiple data-aim-dropzone-target="input" data-action="change->aim-dropzone#list">
//     <ul data-aim-dropzone-target="list"></ul>
export default class extends Controller {
  static targets = ["zone", "input", "list"]

  // A PDF dropped just outside the box would make the browser open it and
  // leave the page, losing the form. Anywhere on the page, a drop does nothing
  // unless it lands on the box.
  connect() {
    this.guard = (event) => {
      if (this.zoneTarget.contains(event.target)) return
      event.preventDefault()
    }
    window.addEventListener("dragover", this.guard)
    window.addEventListener("drop", this.guard)
  }

  disconnect() {
    window.removeEventListener("dragover", this.guard)
    window.removeEventListener("drop", this.guard)
  }

  // Enter or Space on the focused box opens the file chooser.
  key(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    if (event.target !== this.zoneTarget) return
    event.preventDefault()
    this.inputTarget.click()
  }

  over(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("is-over")
  }

  leave(event) {
    event.preventDefault()
    if (event.relatedTarget && this.zoneTarget.contains(event.relatedTarget)) return
    this.zoneTarget.classList.remove("is-over")
  }

  drop(event) {
    event.preventDefault()
    this.zoneTarget.classList.remove("is-over")
    const dropped = Array.from(event.dataTransfer?.files || [])
    if (dropped.length === 0) return

    // Keep what was already chosen and add what was dropped. Only PDFs: the
    // server refuses anything else, so say so here rather than after a trip.
    const transfer = new DataTransfer()
    Array.from(this.inputTarget.files || []).forEach((file) => transfer.items.add(file))
    let refused = 0
    dropped.forEach((file) => {
      if (this.isPdf(file)) transfer.items.add(file)
      else refused += 1
    })
    this.inputTarget.files = transfer.files
    this.list(refused)
  }

  // Open the file chooser when the zone itself is clicked.
  choose(event) {
    if (event.target.closest("input, button, a, label")) return
    this.inputTarget.click()
  }

  list(refused = 0) {
    if (!this.hasListTarget) return
    const files = Array.from(this.inputTarget.files || [])
    this.listTarget.innerHTML = ""
    files.forEach((file) => {
      const item = document.createElement("li")
      item.textContent = `${file.name} (${this.size(file.size)})`
      this.listTarget.appendChild(item)
    })
    if (typeof refused === "number" && refused > 0) {
      const item = document.createElement("li")
      item.className = "aim-dropzone__refused"
      item.textContent = `${refused} file${refused === 1 ? " was" : "s were"} not added: only PDFs can be uploaded.`
      this.listTarget.appendChild(item)
    }
  }

  isPdf(file) {
    return file.type === "application/pdf" || /\.pdf$/i.test(file.name)
  }

  size(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }
}
