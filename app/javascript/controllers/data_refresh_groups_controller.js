import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

export default class extends Controller {
  async toggle(event) {
    const detailId = event.currentTarget.dataset.detailId
    const detailRow = document.getElementById(detailId)
    const expanded = detailRow.hidden

    detailRow.hidden = !expanded
    this.element.querySelectorAll(`[data-detail-id="${detailId}"]`).forEach((trigger) => {
      trigger.setAttribute("aria-expanded", String(expanded))
    })
    if (expanded && detailRow.dataset.detailsUrl && detailRow.dataset.loaded !== "true") {
      await this.loadDetails(detailRow)
    }
  }

  async loadDetails(detailRow) {
    const container = detailRow.querySelector("[data-lazy-details]")
    try {
      const response = await fetch(detailRow.dataset.detailsUrl, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(`Details request failed: ${response.status}`)

      container.innerHTML = await response.text()
      detailRow.dataset.loaded = "true"
    } catch (_error) {
      container.textContent = "Associated files could not be loaded."
    }
  }

  async feedback(event) {
    const action = event.currentTarget.dataset.feedbackAction
    const omsNumber = event.currentTarget.dataset.feedbackOms
    await pbAlert({
      title: `${action} pressed`,
      message: `${action} was pressed for OMS ${omsNumber}.`
    })
  }

  async staging(event) {
    const button = event.currentTarget
    const destructive = button.dataset.stagingMethod === "DELETE"
    if (destructive && !await pbConfirm({
      title: button.dataset.stagingAction,
      message: button.dataset.confirmMessage,
      confirmLabel: "Remove",
      confirmVariant: "deny"
    })) return

    const progress = button.dataset.stagingRemoveOnSuccess === "true"
      ? button.closest("[data-controller~='pdf-preview']")?.querySelector("[data-staging-progress]")
      : null
    const startedAt = performance.now()
    const timer = this.startStagingProgress(progress, startedAt)
    button.disabled = true

    const parameters = new URLSearchParams({
      directory: button.dataset.directory,
      oms_number: button.dataset.omsNumber
    })
    try {
      const response = await fetch(button.dataset.stagingUrl, {
        method: button.dataset.stagingMethod,
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: parameters.toString()
      })
      const contentType = response.headers.get("content-type") || ""
      const result = contentType.includes("application/json") ? await response.json() : {}
      const duration = this.elapsedSeconds(startedAt)
      this.stopStagingProgress(progress, timer)
      if (response.ok && button.dataset.stagingRemoveOnSuccess === "true") this.removeOmsRows(button)

      const title = response.ok && button.dataset.stagingRemoveOnSuccess === "true"
        ? `${button.dataset.omsNumber} Moved to Staging`
        : response.ok ? button.dataset.stagingAction : "Staging failed"
      await pbAlert({
        title,
        message: `${result.message || `The staging request failed (${response.status}).`} ` +
          `Elapsed time: ${duration} seconds.`
      })
    } catch (_error) {
      const duration = this.elapsedSeconds(startedAt)
      this.stopStagingProgress(progress, timer)
      await pbAlert({
        title: "Staging failed",
        message: `The staging request could not be completed. Elapsed time: ${duration} seconds.`
      })
    } finally {
      button.disabled = false
    }
  }

  async batchMove(event) {
    const button = event.currentTarget
    const jobs = this.visibleOmsJobs()
    if (!jobs.length) {
      await pbAlert({ title: "No OMS files to move", message: "The grid has no visible OMS numbers." })
      return
    }

    const destination = button.dataset.batchDestination
    if (!await pbConfirm(this.batchConfirmation(destination, jobs))) return

    const progress = this.element.querySelector("[data-batch-progress]")
    const startedAt = performance.now()
    const timer = this.startBatchProgress(progress, destination, jobs.length, startedAt)
    const successes = []
    const failures = []
    this.setBatchButtonsDisabled(true)

    for (const [index, job] of jobs.entries()) {
      try {
        const result = await this.sendStagingRequest(button.dataset.batchUrl, "POST", job)
        if (result.ok) {
          successes.push(job)
          if (destination === "staging") this.removeOmsRow(job.row)
        } else {
          failures.push({ job, message: result.message })
        }
      } catch (_error) {
        failures.push({ job, message: "The request could not be completed." })
      }
      this.updateBatchProgress(progress, destination, index + 1, jobs.length, startedAt)
    }

    this.stopBatchProgress(progress, timer)
    this.setBatchButtonsDisabled(false)
    await pbAlert(this.batchResult(destination, jobs, successes, failures, startedAt))
  }

  visibleOmsJobs() {
    return Array.from(this.element.querySelectorAll("tr.p2m-maildat-row[data-sort-row]"))
      .filter(row => !row.hidden)
      .map(row => ({
        row,
        omsNumber: row.dataset.omsNumber,
        directory: row.dataset.directory,
        fileCount: Number(row.dataset.associatedFileCount)
      }))
  }

  batchConfirmation(destination, jobs) {
    const omsList = jobs.map(job => destination === "staging"
      ? `${job.omsNumber} (${job.fileCount} files)`
      : job.omsNumber).join(", ")
    const totalFiles = destination === "staging"
      ? jobs.reduce((total, job) => total + job.fileCount, 0)
      : jobs.length
    const detail = destination === "staging"
      ? `This will validate and copy ${totalFiles} associated files for ${jobs.length} visible OMS numbers ` +
        "to 00_SentToUSPS. Successful OMS numbers will be removed from this grid; failures will remain visible."
      : `This will copy one Mail.dat ZIP for each of ${jobs.length} visible OMS numbers ` +
        `to 00_ShippingStation (${totalFiles} files total). Associated files will not be copied.`

    return {
      title: destination === "staging" ? "Move All to Staging" : "Move All to Shipping Station",
      message: `${detail}\n\nOMS numbers: ${omsList}\n\nProcessing will continue if an individual OMS fails.`,
      confirmLabel: "Continue",
      confirmVariant: destination === "staging" ? "approve" : "reassign"
    }
  }

  async sendStagingRequest(url, method, job) {
    const parameters = new URLSearchParams({
      directory: job.directory,
      oms_number: job.omsNumber
    })
    const response = await fetch(url, {
      method,
      headers: {
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: parameters.toString()
    })
    const contentType = response.headers.get("content-type") || ""
    const result = contentType.includes("application/json") ? await response.json() : {}
    return {
      ok: response.ok,
      message: result.message || `The staging request failed (${response.status}).`
    }
  }

  startBatchProgress(progress, destination, total, startedAt) {
    progress.hidden = false
    this.updateBatchProgress(progress, destination, 0, total, startedAt)
    return window.setInterval(() => {
      const completed = Number(progress.dataset.completed)
      this.updateBatchProgress(progress, destination, completed, total, startedAt)
    }, 100)
  }

  updateBatchProgress(progress, destination, completed, total, startedAt) {
    const label = destination === "staging" ? "staging" : "Shipping Station"
    const bar = progress.querySelector("[data-batch-progress-bar]")
    progress.dataset.completed = completed
    bar.max = total
    bar.value = completed
    progress.querySelector("[data-batch-progress-label]").textContent =
      `Moving ${completed} of ${total} OMS numbers to ${label}… ${this.elapsedSeconds(startedAt)} seconds elapsed`
  }

  stopBatchProgress(progress, timer) {
    window.clearInterval(timer)
    progress.hidden = true
  }

  setBatchButtonsDisabled(disabled) {
    this.element.querySelectorAll("[data-batch-move]").forEach(button => {
      button.disabled = disabled
    })
  }

  batchResult(destination, jobs, successes, failures, startedAt) {
    const target = destination === "staging" ? "Staging" : "Shipping Station"
    let message = `${successes.length} of ${jobs.length} OMS numbers moved successfully. ` +
      `Elapsed time: ${this.elapsedSeconds(startedAt)} seconds.`
    if (failures.length) {
      const details = failures.map(({ job, message: failure }) => `${job.omsNumber}: ${failure}`).join("; ")
      message += `\n\n${failures.length} failed and remain visible. ${details}`
    }
    return { title: `Move All to ${target} Complete`, message }
  }

  startStagingProgress(progress, startedAt) {
    if (!progress) return null

    const label = progress.querySelector("[data-staging-progress-label]")
    const update = () => {
      label.textContent = `Moving files… ${this.elapsedSeconds(startedAt)} seconds elapsed`
    }
    progress.hidden = false
    update()
    return window.setInterval(update, 100)
  }

  stopStagingProgress(progress, timer) {
    if (timer) window.clearInterval(timer)
    if (progress) progress.hidden = true
  }

  elapsedSeconds(startedAt) {
    return ((performance.now() - startedAt) / 1000).toFixed(1)
  }

  removeOmsRows(button) {
    const detailRow = button.closest("tr.p2m-maildat-detail")
    const resultRow = detailRow?.previousElementSibling
    if (resultRow?.matches("tr.p2m-maildat-row")) this.removeOmsRow(resultRow)
  }

  removeOmsRow(resultRow) {
    document.getElementById(resultRow.dataset.detailId)?.remove()
    resultRow.remove()
    this.element.querySelectorAll("tr[data-sort-row]").forEach((row, index) => {
      row.classList.toggle("is-alternate", index % 2 === 1)
    })
  }
}
