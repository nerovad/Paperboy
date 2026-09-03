import { Controller } from "@hotwired/stimulus"
import { pbConfirm } from "pb_modal"

export default class extends Controller {
  static values = { catalog: Object, mode: String, oms: String }

  open() {
    const backdrop = document.createElement("div")
    backdrop.className = "pb-modal-backdrop"
    backdrop.innerHTML = this.dialogMarkup()
    document.body.appendChild(backdrop)

    const dialog = backdrop.querySelector(".pb-modal")
    const printer = backdrop.querySelector("[data-printer-select]")
    const queue = backdrop.querySelector("[data-queue-select]")
    const continueButton = backdrop.querySelector("[data-printer-continue]")
    const close = () => backdrop.remove()

    Object.keys(this.catalogValue).forEach((name) => printer.add(new Option(name, name)))
    printer.addEventListener("change", () => {
      queue.replaceChildren(new Option("Select a queue", ""))
      const queues = this.catalogValue[printer.value] || []
      queues.forEach((name) => queue.add(new Option(name, name)))
      queue.disabled = !printer.value
      continueButton.disabled = true
    })
    queue.addEventListener("change", () => { continueButton.disabled = !queue.value })
    backdrop.querySelectorAll("[data-printer-close]").forEach((button) => {
      button.addEventListener("click", close)
    })
    backdrop.addEventListener("click", (event) => { if (event.target === backdrop) close() })
    continueButton.addEventListener("click", async () => {
      const selection = { printer: printer.value, queue: queue.value }
      close()
      await pbConfirm({
        title: "Confirm Printer and Queue",
        message: this.confirmationMessage(selection),
        confirmLabel: this.modeValue === "batch" ? "Send All to Printer" : "Send to Printer"
      })
    })
    dialog.addEventListener("keydown", (event) => { if (event.key === "Escape") close() })
    printer.focus()
  }

  confirmationMessage(selection) {
    if (this.modeValue === "batch") {
      return `Send all visible Mail.dat files to printer ${selection.printer} using queue ${selection.queue}?`
    }

    return `Send OMS ${this.omsValue} to printer ${selection.printer} using queue ${selection.queue}?`
  }

  dialogMarkup() {
    return `
      <div class="pb-modal" role="dialog" aria-modal="true" aria-labelledby="printer-selection-title">
        <div class="pb-modal__header">
          <h3 id="printer-selection-title">Send to Printer</h3>
          <button type="button" class="pb-modal__close" data-printer-close aria-label="Close">✕</button>
        </div>
        <div class="pb-modal__body">
          <div class="form-group">
            <label for="printer-selection-printer">Printer</label>
            <select id="printer-selection-printer" class="form-control" data-printer-select>
              <option value="">Select a printer</option>
            </select>
          </div>
          <div class="form-group">
            <label for="printer-selection-queue">Queue</label>
            <select id="printer-selection-queue" class="form-control" data-queue-select disabled>
              <option value="">Select a queue</option>
            </select>
          </div>
          <div class="pb-modal__actions">
            <button type="button" class="btn" data-printer-close>Cancel</button>
            <button type="button" class="btn approve" data-printer-continue disabled>Continue</button>
          </div>
        </div>
      </div>`
  }
}
