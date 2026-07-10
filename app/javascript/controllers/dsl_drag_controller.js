import { Controller } from "@hotwired/stimulus"

const DRAG_THRESHOLD = 6

export default class extends Controller {
  open(event) {
    if (event.type === "keydown" && !["Enter", " "].includes(event.key)) return
    if (this.suppressClickUntil && Date.now() < this.suppressClickUntil) return

    event.preventDefault()
    window.location.href = event.currentTarget.dataset.href
  }

  mousedown(event) {
    if (event.button !== 0) return

    event.preventDefault()
    this.removeGhosts()
    this.drag = {
      slug: event.currentTarget.dataset.dslSlug,
      key: event.currentTarget.dataset.dslKey,
      enabled: event.currentTarget.dataset.dslEnabled === "true",
      origin: "nav"
    }
    this.startX = event.clientX
    this.startY = event.clientY
    this.dragging = false
    this.boundMousemove = moveEvent => this.mousemove(moveEvent)
    this.boundMouseup = upEvent => this.mouseup(upEvent)
    document.addEventListener("mousemove", this.boundMousemove, true)
    document.addEventListener("mouseup", this.boundMouseup, true)
  }

  mousemove(event) {
    if (!this.drag) return
    if (event.buttons === 0) {
      this.mouseup(event)
      return
    }

    const distance = Math.hypot(event.clientX - this.startX, event.clientY - this.startY)
    if (!this.dragging && distance < DRAG_THRESHOLD) return

    event.preventDefault()
    this.dragging = true
    this.suppressClickUntil = Date.now() + 700
    this.showGhost(event)
    window.DataRunnerDslGroup?.add(this.drag)
  }

  mouseup(event) {
    document.removeEventListener("mousemove", this.boundMousemove, true)
    document.removeEventListener("mouseup", this.boundMouseup, true)
    if (this.dragging) {
      event.preventDefault()
      window.DataRunnerDslGroup?.drop(this.drag, event.clientX, event.clientY)
    }
    this.removeGhost()
    this.drag = null
    this.dragging = false
  }

  showGhost(event) {
    if (!this.ghost) {
      this.ghost = document.createElement("div")
      this.ghost.className = "drag-ghost"
      this.ghost.textContent = this.drag.key
      document.body.appendChild(this.ghost)
    }
    this.ghost.style.left = `${event.clientX + 12}px`
    this.ghost.style.top = `${event.clientY + 12}px`
  }

  removeGhost() {
    this.ghost?.remove()
    this.ghost = null
  }

  removeGhosts() {
    document.querySelectorAll(".drag-ghost").forEach(ghost => ghost.remove())
  }
}
