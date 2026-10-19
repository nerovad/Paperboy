import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

// Edit PDF (#181): the invoice's pages as thumbnails, drawn with pdf.js (as
// OCR does). Drag to reorder; turn, remove, crop and add text to each; add
// pages from other PDFs. Nothing changes until Apply, which posts the pages
// as JSON (Aim::PdfEdit reads them) with any added PDFs.
//
// Crop and text are fractions of the page as seen (after turning), from its
// top left; text is placed on the cropped page.
const PDF_JS_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"
const PDF_WORKER_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js"
const THUMB_WIDTH = 170
const BIG_WIDTH = 660

export default class extends Controller {
  static targets = ["grid", "status", "pages", "inserts", "insertPicker", "form",
                    "modal", "modalTitle", "canvas", "cropTools", "textTools", "textInput", "textSize", "textList"]
  static values = { pdfUrl: String, pageCount: Number }

  // Starts clean every time: Stimulus can connect twice (Turbo's cache, a
  // dialog), and a load that is no longer the latest is dropped.
  async connect() {
    const load = (this.load = Symbol("load"))
    this.sources = []
    this.cards = []
    this.insertFiles = []
    this.gridTarget.replaceChildren()
    try {
      await this.loadPdfJs()
      const doc = await window.pdfjsLib.getDocument({ url: this.pdfUrlValue, withCredentials: true }).promise
      if (load !== this.load) return
      this.sources.push({ doc, name: "this invoice" })
      for (let number = 1; number <= doc.numPages; number++) this.addCard(0, number, `Page ${number}`)
      this.statusTarget.textContent = ""
    } catch (error) {
      console.error(error)
      this.statusTarget.textContent = "The PDF could not be shown here. Swapping it still works."
    }
  }

  disconnect() { this.load = null }

  // --- pages -----------------------------------------------------------------

  addCard(source, page, label) {
    const card = { id: crypto.randomUUID(), source, page, label, rotate: 0, crop: null, texts: [], removed: false }
    this.cards.push(card)
    const element = document.createElement("figure")
    element.className = "aim-pdf-card"
    element.draggable = true
    element.dataset.id = card.id
    element.innerHTML = `
      <div class="aim-pdf-card__page"><canvas></canvas></div>
      <figcaption>
        <span class="aim-pdf-card__label"></span>
        <span class="aim-pdf-card__tools">
          <button type="button" class="btn compact ghost" data-act="left">Turn left</button>
          <button type="button" class="btn compact ghost" data-act="right">Turn right</button>
          <button type="button" class="btn compact ghost" data-act="crop">Crop</button>
          <button type="button" class="btn compact ghost" data-act="text">Text</button>
          <button type="button" class="btn compact deny" data-act="remove">Remove</button>
        </span>
      </figcaption>`
    element.querySelector(".aim-pdf-card__label").textContent = label
    element.addEventListener("click", (event) => this.act(event, card))
    element.addEventListener("dragstart", (event) => { this.dragged = element; event.dataTransfer.effectAllowed = "move" })
    element.addEventListener("dragover", (event) => this.dragOver(event, element))
    element.addEventListener("dragend", () => { this.dragged = null })
    this.gridTarget.appendChild(element)
    this.drawThumb(card)
  }

  act(event, card) {
    const button = event.target.closest("[data-act]")
    if (!button) return
    const action = button.dataset.act
    if (action === "left" || action === "right") {
      card.rotate = (card.rotate + (action === "right" ? 90 : 270)) % 360
      card.crop = null
      card.texts = []
      this.drawThumb(card)
    } else if (action === "remove") {
      card.removed = !card.removed
      this.element.querySelector(`[data-id="${card.id}"]`).classList.toggle("is-removed", card.removed)
      button.textContent = card.removed ? "Keep" : "Remove"
    } else {
      this.openPage(card, action)
    }
  }

  dragOver(event, target) {
    event.preventDefault()
    if (!this.dragged || this.dragged === target) return
    const box = target.getBoundingClientRect()
    const after = event.clientX > box.left + box.width / 2
    target.parentNode.insertBefore(this.dragged, after ? target.nextSibling : target)
  }

  async addPdf() {
    const file = this.insertPickerTarget.files[0]
    this.insertPickerTarget.value = ""
    if (!file) return
    if (this.insertFiles.length >= 5) return pbAlert({ title: "Too many PDFs", message: "Add pages from at most 5 PDFs at a time." })
    try {
      const doc = await window.pdfjsLib.getDocument({ data: await file.arrayBuffer() }).promise
      this.insertFiles.push(file)
      const source = this.insertFiles.length
      this.sources[source] = { doc, name: file.name }
      for (let number = 1; number <= doc.numPages; number++) this.addCard(source, number, `${file.name} p${number}`)
    } catch (error) {
      console.error(error)
      pbAlert({ title: "Not added", message: `${file.name} could not be read as a PDF.` })
    }
  }

  async drawThumb(card) {
    const canvas = this.element.querySelector(`[data-id="${card.id}"] canvas`)
    const viewport = await this.render(card, canvas, THUMB_WIDTH)
    this.drawMarks(canvas.getContext("2d"), card, viewport)
  }

  // Renders the page turned as the card says, +width+ wide; returns the viewport.
  async render(card, canvas, width) {
    const page = await this.sources[card.source].doc.getPage(card.page)
    const rotation = (page.rotate + card.rotate) % 360
    const plain = page.getViewport({ scale: 1, rotation })
    const viewport = page.getViewport({ scale: width / plain.width, rotation })
    canvas.width = Math.round(viewport.width)
    canvas.height = Math.round(viewport.height)
    await page.render({ canvasContext: canvas.getContext("2d"), viewport }).promise
    return viewport
  }

  // The crop (outside dimmed) and the text boxes, over a rendered page.
  drawMarks(context, card, viewport) {
    const width = viewport.width
    const height = viewport.height
    const crop = card.crop || { left: 0, top: 0, right: 1, bottom: 1 }
    if (card.crop) {
      context.fillStyle = "rgba(15, 23, 42, 0.55)"
      context.fillRect(0, 0, width, crop.top * height)
      context.fillRect(0, crop.bottom * height, width, (1 - crop.bottom) * height)
      context.fillRect(0, crop.top * height, crop.left * width, (crop.bottom - crop.top) * height)
      context.fillRect(crop.right * width, crop.top * height, (1 - crop.right) * width, (crop.bottom - crop.top) * height)
    }
    context.fillStyle = "#000"
    const cropWidth = (crop.right - crop.left) * width
    const cropHeight = (crop.bottom - crop.top) * height
    card.texts.forEach((text) => {
      const size = text.size * viewport.scale
      context.font = `${size}px Helvetica, Arial, sans-serif`
      text.text.split(/\r?\n/).forEach((line, index) => {
        const x = (crop.left * width) + (text.x * cropWidth)
        const y = (crop.top * height) + (text.y * cropHeight) + (size * ((index * 1.2) + 1))
        context.fillText(line, x, y)
      })
    })
  }

  // --- crop and text, on a big view ------------------------------------------

  async openPage(card, mode) {
    this.current = card
    this.mode = mode
    this.draft = card.crop ? { ...card.crop } : null
    this.point = null
    this.modalTitleTarget.textContent = `${mode === "crop" ? "Crop" : "Add text to"} ${card.label}`
    this.cropToolsTarget.hidden = mode !== "crop"
    this.textToolsTarget.hidden = mode !== "text"
    this.modalTarget.hidden = false
    this.bigViewport = await this.render(card, this.canvasTarget, BIG_WIDTH)
    this.bigImage = this.canvasTarget.getContext("2d").getImageData(0, 0, this.canvasTarget.width, this.canvasTarget.height)
    this.redrawBig()
    this.listTexts()
  }

  closePage() {
    this.modalTarget.hidden = true
    this.current = null
  }

  redrawBig() {
    const context = this.canvasTarget.getContext("2d")
    context.putImageData(this.bigImage, 0, 0)
    const shown = { ...this.current, crop: this.mode === "crop" ? this.draft : this.current.crop }
    this.drawMarks(context, shown, this.bigViewport)
    if (this.mode === "crop" && this.draft) {
      context.strokeStyle = "#16a34a"
      context.lineWidth = 2
      const { width, height } = this.canvasTarget
      context.strokeRect(this.draft.left * width, this.draft.top * height,
                         (this.draft.right - this.draft.left) * width, (this.draft.bottom - this.draft.top) * height)
    }
    if (this.mode === "text" && this.point) {
      context.fillStyle = "#dc2626"
      context.beginPath()
      context.arc(this.point.fx * this.canvasTarget.width, this.point.fy * this.canvasTarget.height, 5, 0, Math.PI * 2)
      context.fill()
    }
  }

  fraction(event) {
    const box = this.canvasTarget.getBoundingClientRect()
    return { fx: Math.min(1, Math.max(0, (event.clientX - box.left) / box.width)),
             fy: Math.min(1, Math.max(0, (event.clientY - box.top) / box.height)) }
  }

  pointerDown(event) {
    if (!this.current) return
    const at = this.fraction(event)
    if (this.mode === "crop") {
      this.anchor = at
      this.draft = { left: at.fx, top: at.fy, right: at.fx, bottom: at.fy }
    } else {
      this.point = at
    }
    this.redrawBig()
  }

  pointerMove(event) {
    if (this.mode !== "crop" || !this.anchor) return
    const at = this.fraction(event)
    this.draft = { left: Math.min(this.anchor.fx, at.fx), right: Math.max(this.anchor.fx, at.fx),
                   top: Math.min(this.anchor.fy, at.fy), bottom: Math.max(this.anchor.fy, at.fy) }
    this.redrawBig()
  }

  pointerUp() { this.anchor = null }

  saveCrop() {
    const crop = this.draft
    if (!crop || crop.right - crop.left < 0.02 || crop.bottom - crop.top < 0.02) {
      return pbAlert({ title: "No crop", message: "Drag a box over the part of the page to keep." })
    }
    this.current.crop = crop
    this.current.texts = []
    this.drawThumb(this.current)
    this.closePage()
  }

  clearCrop() {
    this.current.crop = null
    this.drawThumb(this.current)
    this.closePage()
  }

  addText() {
    const text = this.textInputTarget.value.trim()
    if (!this.point || !text) return pbAlert({ title: "Text not added", message: "Click where the text goes, then type it." })
    const crop = this.current.crop || { left: 0, top: 0, right: 1, bottom: 1 }
    const x = (this.point.fx - crop.left) / (crop.right - crop.left)
    const y = (this.point.fy - crop.top) / (crop.bottom - crop.top)
    if (x < 0 || x > 1 || y < 0 || y > 1) return pbAlert({ title: "Text not added", message: "Put the text inside the cropped page." })
    this.current.texts.push({ x, y, size: Number(this.textSizeTarget.value), text })
    this.textInputTarget.value = ""
    this.point = null
    this.redrawBig()
    this.listTexts()
    this.drawThumb(this.current)
  }

  listTexts() {
    this.textListTarget.replaceChildren(...(this.current?.texts || []).map((text, index) => {
      const item = document.createElement("li")
      item.textContent = text.text.replace(/\s+/g, " ").slice(0, 60)
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "btn compact ghost"
      remove.textContent = "Remove"
      remove.addEventListener("click", () => {
        this.current.texts.splice(index, 1)
        this.redrawBig()
        this.listTexts()
        this.drawThumb(this.current)
      })
      item.append(" ", remove)
      return item
    }))
  }

  // --- apply -----------------------------------------------------------------

  async apply(event) {
    event.preventDefault()
    const order = [...this.gridTarget.querySelectorAll(".aim-pdf-card")].map((element) => element.dataset.id)
    const pages = order.map((id) => this.cards.find((card) => card.id === id)).filter((card) => !card.removed)
      .map(({ source, page, rotate, crop, texts }) => ({ source, page, rotate, crop, texts }))
    if (pages.length === 0) return pbAlert({ title: "Nothing to keep", message: "Keep at least one page." })
    const ok = await pbConfirm({ title: "Apply changes", message: `Save the PDF with ${pages.length} page${pages.length === 1 ? "" : "s"}? The current one is kept as a version.`,
                                 confirmLabel: "Apply", confirmVariant: "approve" })
    if (!ok) return
    this.pagesTarget.value = JSON.stringify(pages)
    const files = new DataTransfer()
    this.insertFiles.forEach((file) => files.items.add(file))
    this.insertsTarget.files = files.files
    this.formTarget.submit()
  }

  loadPdfJs() {
    if (window.pdfjsLib) return Promise.resolve()
    return new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = PDF_JS_URL
      script.onload = () => { window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDF_WORKER_URL; resolve() }
      script.onerror = reject
      document.head.appendChild(script)
    })
  }
}
