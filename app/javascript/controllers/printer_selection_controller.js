import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

export default class extends Controller {
  static batchConcurrency = 4
  static values = { catalog: Object, directory: String, mode: String, oms: String, operation: String, url: String }

  open() {
    const jobs = this.modeValue === "batch" ? this.visibleJobs() : [this.selectedJob()]
    if (!jobs.length || jobs.some(job => !job)) {
      void pbAlert({ title: "No files selected", message: "Select at least one file first." })
      return
    }

    const backdrop = document.createElement("div")
    backdrop.className = "pb-modal-backdrop"
    backdrop.innerHTML = this.dialogMarkup()
    document.body.appendChild(backdrop)

    const dialog = backdrop.querySelector(".pb-modal")
    const printer = backdrop.querySelector("[data-printer-select]")
    const queue = backdrop.querySelector("[data-queue-select]")
    const continueButton = backdrop.querySelector("[data-printer-continue]")
    const close = (clearSelection = true) => {
      backdrop.remove()
      if (clearSelection) this.clearSelectedFiles()
    }

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
      close(false)
      if (!await pbConfirm({
        title: this.isRemoval ? "Confirm Removal from Printer" : "Confirm Printer and Queue",
        message: this.confirmationMessage(selection),
        confirmLabel: this.isRemoval ? "Remove from Printer" :
          this.modeValue === "batch" ? "Send All to Printer" : "Send to Printer",
        confirmVariant: this.isRemoval ? "deny" : "approve"
      })) {
        this.clearSelectedFiles()
        return
      }

      this.clearSelectedFiles()
      await this.copyFiles(selection, jobs)
    })
    dialog.addEventListener("keydown", (event) => { if (event.key === "Escape") close() })
    printer.focus()
  }

  confirmationMessage(selection) {
    if (this.isRemoval) {
      return `Remove the selected files for OMS ${this.omsValue} from printer ${selection.printer} ` +
        `queue ${selection.queue}?`
    }
    if (this.modeValue === "batch") {
      return `Send all associated files for the visible OMS numbers to printer ${selection.printer} ` +
        `using queue ${selection.queue}?`
    }

    return `Send OMS ${this.omsValue} to printer ${selection.printer} using queue ${selection.queue}?`
  }

  async copyFiles(selection, jobs) {
    const progress = this.progressElement()
    const startedAt = performance.now()
    let completed = 0
    const successes = []
    const failures = []
    let nextIndex = 0
    this.setProgress(progress, completed, jobs.length, startedAt)
    const timer = window.setInterval(() => this.setProgress(progress, completed, jobs.length, startedAt), 100)

    const processJobs = async () => {
      while (nextIndex < jobs.length) {
        const job = jobs[nextIndex++]
        try {
          const result = await this.sendRequest(selection, job)
          result.ok ? successes.push(job) : failures.push(`${job.omsNumber}: ${result.message}`)
        } catch (_error) {
          failures.push(`${job.omsNumber}: The request could not be completed.`)
        }
        completed += 1
        this.setProgress(progress, completed, jobs.length, startedAt)
      }
    }
    await Promise.all(Array.from({ length: Math.min(this.constructor.batchConcurrency, jobs.length) }, processJobs))
    window.clearInterval(timer)
    progress.hidden = true

    const verb = this.isRemoval ? "processed for removal" : "copied"
    let message = `${successes.length} of ${jobs.length} OMS numbers ${verb} successfully. ` +
      `Elapsed time: ${this.elapsedSeconds(startedAt)} seconds.`
    if (failures.length) message += `\n\n${failures.length} failed. ${failures.join("; ")}`
    const action = this.isRemoval ? "Printer Removal" : "Printer Copy"
    await pbAlert({ title: failures.length ? `${action} Complete with Errors` : `${action} Complete`, message })
  }

  selectedJob() {
    const container = this.element.closest("[data-controller~='pdf-preview']")
    const selectedFiles = Array.from(container?.querySelectorAll("input[name='selected_files[]']:checked") || [])
      .map(input => input.value)
    if (!selectedFiles.length) return null

    return { omsNumber: this.omsValue, directory: this.directoryValue, selectedFiles }
  }

  clearSelectedFiles() {
    const container = this.element.closest("[data-controller~='pdf-preview']")
    container?.querySelectorAll("input[name='selected_files[]']:checked")
      .forEach(input => { input.checked = false })
  }

  visibleJobs() {
    const section = this.element.closest("section")
    return Array.from(section.querySelectorAll("tr.p2m-maildat-row[data-sort-row]"))
      .filter(row => !row.hidden)
      .map(row => ({ omsNumber: row.dataset.omsNumber, directory: row.dataset.directory }))
  }

  async sendRequest(selection, job) {
    const parameters = new URLSearchParams({
      directory: job.directory,
      oms_number: job.omsNumber,
      printer: selection.printer,
      queue: selection.queue
    })
    job.selectedFiles?.forEach(name => parameters.append("selected_files[]", name))
    const response = await fetch(this.urlValue, {
      method: this.isRemoval ? "DELETE" : "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: parameters.toString()
    })
    const result = (response.headers.get("content-type") || "").includes("application/json")
      ? await response.json() : {}
    return { ok: response.ok, message: result.message || `Printer copy failed (${response.status}).` }
  }

  progressElement() {
    const scope = this.modeValue === "batch"
      ? this.element.closest("section")
      : this.element.closest("[data-controller~='pdf-preview']")
    let progress = scope.querySelector("[data-printer-progress]")
    if (!progress) {
      progress = document.createElement("div")
      progress.dataset.printerProgress = ""
      progress.innerHTML = '<progress data-printer-progress-bar max="1" value="0"></progress> ' +
        '<span data-printer-progress-label aria-live="polite"></span>'
      scope.appendChild(progress)
    }
    progress.hidden = false
    return progress
  }

  setProgress(progress, completed, total, startedAt) {
    const bar = progress.querySelector("[data-printer-progress-bar]")
    bar.max = total
    bar.value = completed
    progress.querySelector("[data-printer-progress-label]").textContent =
      `${completed} of ${total} printer copies completed · ${this.elapsedSeconds(startedAt)} seconds elapsed`
  }

  elapsedSeconds(startedAt) {
    return ((performance.now() - startedAt) / 1000).toFixed(1)
  }

  get isRemoval() {
    return this.operationValue === "remove"
  }

  dialogMarkup() {
    return `
      <div class="pb-modal" role="dialog" aria-modal="true" aria-labelledby="printer-selection-title">
        <div class="pb-modal__header">
          <h3 id="printer-selection-title">${this.isRemoval ? "Remove from Printer" : "Send to Printer"}</h3>
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
