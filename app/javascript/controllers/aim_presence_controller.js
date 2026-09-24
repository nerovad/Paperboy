import { Controller } from "@hotwired/stimulus"

// Keep an invoice's working lock while its review page is open, and let it
// go when the page is left. The server lets a lock lapse by itself if the
// check-ins stop, so a lost goodbye (a closed laptop) never leaves it stuck.
export default class extends Controller {
  static values = { lockUrl: String, unlockUrl: String, every: { type: Number, default: 30000 } }

  connect() {
    this.timer = setInterval(() => this.checkIn(), this.everyValue)
    this.leave = () => this.release()
    window.addEventListener("pagehide", this.leave)
  }

  disconnect() {
    clearInterval(this.timer)
    window.removeEventListener("pagehide", this.leave)
    this.release()
  }

  checkIn() {
    fetch(this.lockUrlValue, { method: "PATCH", headers: { "X-CSRF-Token": this.token() }, keepalive: true })
      .catch(() => {})
  }

  release() {
    if (this.released) return
    this.released = true
    const body = new FormData()
    body.append("authenticity_token", this.token())
    navigator.sendBeacon(this.unlockUrlValue, body)
  }

  token() {
    return document.querySelector("meta[name=csrf-token]")?.content || ""
  }
}
