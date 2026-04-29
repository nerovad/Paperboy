import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "status", "acknowledgedInput"]
  static values = {
    acknowledgeable: Boolean,
    label: String,
    text: String
  }

  connect() {
    if (this.acknowledgeableValue) {
      this.element.classList.add("information-field--required")
      this.renderStatus(false)
      const form = this.element.closest("form")
      if (form && !form.dataset.informationGuard) {
        form.dataset.informationGuard = "true"
        form.addEventListener("submit", this.guardSubmit.bind(this), true)
      }
    } else {
      this.renderStatus(null)
    }
  }

  open(event) {
    if (event) event.preventDefault()
    this.buildModal()
    document.body.appendChild(this.modal)
    requestAnimationFrame(() => this.modal.classList.add("show"))
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.modal) return
    this.modal.classList.remove("show")
    this.modal.remove()
    this.modal = null
  }

  agree(event) {
    if (event) event.preventDefault()
    this.acknowledged = true
    this.acknowledgedInputTarget.value = "1"
    this.renderStatus(true)
    this.element.classList.add("information-field--acknowledged")
    this.close()
  }

  guardSubmit(event) {
    const fields = event.target.querySelectorAll(".information-field--required")
    const unacknowledged = Array.from(fields).filter((f) => !f.classList.contains("information-field--acknowledged"))
    if (unacknowledged.length > 0) {
      event.preventDefault()
      event.stopImmediatePropagation()
      const labels = unacknowledged.map((f) => f.dataset.informationFieldLabelValue || "Information").join(", ")
      alert(`You must agree to the following before submitting: ${labels}`)
      unacknowledged[0].scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }

  renderStatus(acknowledged) {
    if (!this.hasStatusTarget) return
    if (acknowledged === true) {
      this.statusTarget.textContent = "✓ Acknowledged"
      this.statusTarget.className = "information-status information-status--acknowledged"
    } else if (acknowledged === false) {
      this.statusTarget.textContent = "Not yet acknowledged"
      this.statusTarget.className = "information-status information-status--pending"
    } else {
      this.statusTarget.textContent = ""
      this.statusTarget.className = "information-status"
    }
  }

  buildModal() {
    const modal = document.createElement("div")
    modal.className = "information-modal-backdrop"
    modal.addEventListener("click", (e) => {
      if (e.target === modal) this.close()
    })

    const content = document.createElement("div")
    content.className = "information-modal"
    content.setAttribute("role", "dialog")
    content.setAttribute("aria-modal", "true")

    const header = document.createElement("div")
    header.className = "information-modal__header"
    const title = document.createElement("h3")
    title.textContent = this.labelValue || "Information"
    const close = document.createElement("button")
    close.type = "button"
    close.className = "information-modal__close"
    close.setAttribute("aria-label", "Close")
    close.textContent = "✕"
    close.addEventListener("click", () => this.close())
    header.appendChild(title)
    header.appendChild(close)

    const body = document.createElement("div")
    body.className = "information-modal__body"
    const text = (this.textValue || "").toString()
    text.split(/\n{2,}/).forEach((para) => {
      if (!para.trim()) return
      const p = document.createElement("p")
      p.textContent = para
      body.appendChild(p)
    })
    if (!body.childNodes.length) {
      const p = document.createElement("p")
      p.textContent = text
      body.appendChild(p)
    }

    const actions = document.createElement("div")
    actions.className = "information-modal__actions"

    if (this.acknowledgeableValue) {
      const cancel = document.createElement("button")
      cancel.type = "button"
      cancel.className = "btn"
      cancel.textContent = "Cancel"
      cancel.addEventListener("click", () => this.close())

      const agree = document.createElement("button")
      agree.type = "button"
      agree.className = "btn approve"
      agree.textContent = "I Agree"
      agree.addEventListener("click", (e) => this.agree(e))

      actions.appendChild(cancel)
      actions.appendChild(agree)
    } else {
      const closeBtn = document.createElement("button")
      closeBtn.type = "button"
      closeBtn.className = "btn"
      closeBtn.textContent = "Close"
      closeBtn.addEventListener("click", () => this.close())
      actions.appendChild(closeBtn)
    }

    content.appendChild(header)
    content.appendChild(body)
    content.appendChild(actions)
    modal.appendChild(content)
    this.modal = modal
  }
}
