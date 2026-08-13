import { Controller } from "@hotwired/stimulus"

const PDF_JS_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"
const PDF_WORKER_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js"
const TESSERACT_URL = "https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"

export default class extends Controller {
  static values = { pdfUrl: String }

  connect() {
    this.frame = this.element.querySelector(".aim-pdf-frame")
    this.canvasViewer = this.element.querySelector("#aim-ocr-canvas-viewer")
    this.loadingIndicator = this.element.querySelector("#loading-indicator")
    this.activeOcrTargetName = null
    this.activeOcrButton = null
    this.isRendered = false
    this.boundClick = this.handleClick.bind(this)
    this.element.addEventListener("click", this.boundClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.boundClick)
  }

  async handleClick(event) {
    const button = event.target.closest(".btn-ocr")
    if (!button || !this.element.contains(button)) return

    event.preventDefault()
    const targetName = button.getAttribute("data-ocr-target-name")

    if (this.activeOcrTargetName === targetName) {
      this.deactivateOcrMode()
    } else {
      try {
        await this.activateOcrMode(targetName, button)
      } catch (error) {
        console.error("AIM OCR setup failed:", error)
        this.setStatus("OCR could not start. Check the browser console for details.")
        this.resetActiveButton()
        this.activeOcrTargetName = null
        this.activeOcrButton = null
      }
    }
  }

  async activateOcrMode(targetName, button) {
    if (this.activeOcrButton) {
      this.activeOcrButton.classList.remove("active-ocr")
      this.activeOcrButton.innerText = "OCR"
    }

    this.activeOcrTargetName = targetName
    this.activeOcrButton = button
    button.classList.add("active-ocr")
    button.innerText = "Cancel"

    await this.ensurePdfRendered()
    this.canvasViewer.classList.add("ocr-mode")
  }

  deactivateOcrMode() {
    this.resetActiveButton()

    this.activeOcrTargetName = null
    this.activeOcrButton = null
    this.canvasViewer.classList.remove("ocr-mode")
    this.showNativeViewer()
  }

  async ensurePdfRendered() {
    this.showOcrViewer()
    if (this.isRendered) return

    this.setStatus("Loading OCR pages...")
    await this.ensureLibraries()

    const pdfDocument = await window.pdfjsLib.getDocument({
      url: this.pdfUrlValue,
      withCredentials: true
    }).promise

    this.removeStatus()
    this.canvasViewer.querySelectorAll(".aim-pdf-page").forEach((element) => element.remove())

    for (let pageNumber = 1; pageNumber <= pdfDocument.numPages; pageNumber += 1) {
      const page = await pdfDocument.getPage(pageNumber)
      const pageElement = document.createElement("div")
      pageElement.className = "aim-pdf-page"

      const canvas = document.createElement("canvas")
      const context = canvas.getContext("2d")
      const viewport = page.getViewport({ scale: 1.25 })

      canvas.height = viewport.height
      canvas.width = viewport.width

      pageElement.appendChild(canvas)
      this.canvasViewer.appendChild(pageElement)

      await page.render({ canvasContext: context, viewport }).promise
      this.setupOcrDrawing(pageElement, canvas)
    }

    this.isRendered = true
  }

  setupOcrDrawing(pageElement, canvas) {
    let isDrawing = false
    let startX = 0
    let startY = 0
    let selectionBox = null

    pageElement.addEventListener("mousedown", (event) => {
      if (!this.activeOcrTargetName) return

      isDrawing = true
      const rect = pageElement.getBoundingClientRect()
      startX = event.clientX - rect.left
      startY = event.clientY - rect.top

      selectionBox = document.createElement("div")
      selectionBox.className = "aim-ocr-selection"
      selectionBox.style.left = `${startX}px`
      selectionBox.style.top = `${startY}px`
      pageElement.appendChild(selectionBox)
    })

    pageElement.addEventListener("mousemove", (event) => {
      if (!isDrawing || !selectionBox) return

      const rect = pageElement.getBoundingClientRect()
      const currentX = event.clientX - rect.left
      const currentY = event.clientY - rect.top
      const left = Math.min(startX, currentX)
      const top = Math.min(startY, currentY)
      const width = Math.abs(startX - currentX)
      const height = Math.abs(startY - currentY)

      selectionBox.style.left = `${left}px`
      selectionBox.style.top = `${top}px`
      selectionBox.style.width = `${width}px`
      selectionBox.style.height = `${height}px`
    })

    pageElement.addEventListener("mouseup", (event) => {
      if (!isDrawing) return
      isDrawing = false

      const rect = pageElement.getBoundingClientRect()
      const endX = event.clientX - rect.left
      const endY = event.clientY - rect.top
      const x = Math.min(startX, endX)
      const y = Math.min(startY, endY)
      const width = Math.abs(startX - endX)
      const height = Math.abs(startY - endY)

      if (selectionBox) selectionBox.remove()
      selectionBox = null

      if (width > 5 && height > 5) {
        this.performOcrOnArea(canvas, pageElement, x, y, width, height)
      }
    })
  }

  async performOcrOnArea(canvas, pageElement, x, y, width, height) {
    const targetName = this.activeOcrTargetName
    const inputElement = document.getElementsByName(targetName)[0]

    if (!inputElement) {
      this.deactivateOcrMode()
      return
    }

    const scaleX = canvas.width / pageElement.clientWidth
    const scaleY = canvas.height / pageElement.clientHeight
    const tempCanvas = document.createElement("canvas")

    tempCanvas.width = width * scaleX
    tempCanvas.height = height * scaleY
    tempCanvas
      .getContext("2d")
      .drawImage(canvas, x * scaleX, y * scaleY, tempCanvas.width, tempCanvas.height, 0, 0, tempCanvas.width, tempCanvas.height)

    try {
      this.setActiveButtonText("Reading...")
      const result = await window.Tesseract.recognize(tempCanvas.toDataURL("image/png"), "eng")
      inputElement.value = result.data.text.trim()
      inputElement.dispatchEvent(new Event("input", { bubbles: true }))
      inputElement.dispatchEvent(new Event("change", { bubbles: true }))
    } catch (error) {
      console.error("Tesseract OCR failed:", error)
      this.setStatus("OCR could not read that selection.")
    }

    this.deactivateOcrMode()
  }

  async ensureLibraries() {
    await this.loadScript(PDF_JS_URL, "pdfjsLib")
    window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDF_WORKER_URL
    await this.loadScript(TESSERACT_URL, "Tesseract")
  }

  loadScript(src, globalName) {
    if (window[globalName]) return Promise.resolve()

    return new Promise((resolve, reject) => {
      const existingScript = document.querySelector(`script[src="${src}"]`)
      if (existingScript) {
        existingScript.addEventListener("load", resolve, { once: true })
        existingScript.addEventListener("error", reject, { once: true })
        return
      }

      const script = document.createElement("script")
      script.src = src
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }

  showNativeViewer() {
    this.frame.classList.remove("is-hidden")
    this.canvasViewer.classList.remove("is-active", "ocr-mode")
  }

  showOcrViewer() {
    this.frame.classList.add("is-hidden")
    this.canvasViewer.classList.add("is-active")
  }

  setStatus(message) {
    if (!this.loadingIndicator) {
      this.loadingIndicator = document.createElement("div")
      this.loadingIndicator.id = "loading-indicator"
      this.loadingIndicator.className = "aim-ocr-status"
      this.canvasViewer.appendChild(this.loadingIndicator)
    }

    this.loadingIndicator.textContent = message
  }

  removeStatus() {
    if (this.loadingIndicator) this.loadingIndicator.remove()
    this.loadingIndicator = null
  }

  setActiveButtonText(text) {
    if (this.activeOcrButton) this.activeOcrButton.innerText = text
  }

  resetActiveButton() {
    if (!this.activeOcrButton) return

    this.activeOcrButton.classList.remove("active-ocr")
    this.activeOcrButton.innerText = "OCR"
  }
}
