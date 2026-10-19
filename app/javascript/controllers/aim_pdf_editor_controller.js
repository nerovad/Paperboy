import { Controller } from "@hotwired/stimulus"
import { pbAlert, pbConfirm } from "pb_modal"

// Edit PDF (#181), in the review page's Document Preview: Edit swaps the
// viewer for a page strip (click to look, drag to reorder) and the chosen
// page big, with one toolbar. Crop by dragging on the big page, add text by
// clicking on it. Nothing changes until Apply, which posts the pages as JSON
// (Aim::PdfEdit reads them) with any added PDFs; Cancel puts the viewer back.
//
// Crop and text are fractions of the page as seen (after turning), from its
// top left; text is placed on the cropped page. Pages are drawn with pdf.js,
// as OCR does.
const PDF_JS_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"
const PDF_WORKER_URL = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js"
const THUMB_WIDTH = 110
const EDGE = 10 // px from a crop edge that grabs it
const SCROLL_EDGE = 36 // px from the panel edge that scrolls it while dragging

export default class extends Controller {
  static targets = ["viewer", "editor", "strip", "stage", "status", "hint", "pageLabel", "removeButton",
                    "textBar", "textInput", "textSize", "textList", "pages", "inserts", "insertPicker", "form", "openButton", "reread", "zoomLabel"]
  static values = { pdfUrl: String }

  // --- opening and closing ---------------------------------------------------

  async open() {
    this.viewerTarget.hidden = true
    this.editorTarget.hidden = false
    this.openButtonTarget.hidden = true
    if (this.loaded) return this.drawStage()
    const load = (this.load = Symbol("load"))
    this.sources = []
    this.cards = []
    this.insertFiles = []
    this.mode = "view"
    this.stripTarget.replaceChildren()
    this.statusTarget.textContent = "Loading pages…"
    try {
      await this.loadPdfJs()
      const doc = await window.pdfjsLib.getDocument({ url: this.pdfUrlValue, withCredentials: true }).promise
      if (load !== this.load) return
      this.sources.push({ doc, name: "this invoice" })
      for (let number = 1; number <= doc.numPages; number++) this.addCard(0, number, `Page ${number}`)
      this.loaded = true
      this.statusTarget.textContent = ""
      this.select(this.cards[0])
    } catch (error) {
      console.error(error)
      this.statusTarget.textContent = "The PDF could not be shown here. Swapping it still works."
    }
  }

  async cancel() {
    if (this.changed && !(await pbConfirm({ title: "Leave the editor", message: "Your changes have not been applied. Leave them?",
                                            confirmLabel: "Leave", confirmVariant: "deny" }))) return
    this.load = null
    this.loaded = false
    this.changed = false
    this.editorTarget.hidden = true
    this.viewerTarget.hidden = false
    this.openButtonTarget.hidden = false
  }

  disconnect() { this.load = null }

  // --- the strip ---------------------------------------------------------------

  addCard(source, page, label) {
    const card = { id: crypto.randomUUID(), source, page, label, rotate: 0, crop: null, texts: [], removed: false }
    this.cards.push(card)
    const element = document.createElement("button")
    element.type = "button"
    element.className = "aim-pdf-thumb"
    element.draggable = true
    element.dataset.id = card.id
    element.innerHTML = "<canvas></canvas><span></span>"
    element.querySelector("span").textContent = label
    element.addEventListener("click", () => this.select(card))
    element.addEventListener("dragstart", (event) => { this.dragged = element; event.dataTransfer.effectAllowed = "move" })
    element.addEventListener("dragover", (event) => this.dragOver(event, element))
    element.addEventListener("dragend", () => { this.dragged = null; if (this.current) this.showLabel() })
    this.stripTarget.appendChild(element)
    this.drawThumb(card)
    return card
  }

  dragOver(event, target) {
    event.preventDefault()
    if (!this.dragged || this.dragged === target) return
    const box = target.getBoundingClientRect()
    const after = event.clientY > box.top + box.height / 2
    target.parentNode.insertBefore(this.dragged, after ? target.nextSibling : target)
    this.changed = true
  }

  thumb(card) { return this.stripTarget.querySelector(`[data-id="${card.id}"]`) }

  select(card) {
    this.current = card
    this.stripTarget.querySelectorAll(".aim-pdf-thumb").forEach((element) => element.classList.toggle("is-current", element.dataset.id === card.id))
    this.setMode("view")
  }

  // "Page 2 · 1 of 3", following the strip's order.
  showLabel() {
    const order = [...this.stripTarget.querySelectorAll(".aim-pdf-thumb")].map((element) => element.dataset.id)
    const position = order.indexOf(this.current.id) + 1
    this.pageLabelTarget.textContent = `${this.current.label} · ${position} of ${order.length}${this.current.removed ? " · removed" : ""}`
    this.removeButtonTarget.textContent = this.current.removed ? "Keep page" : "Remove page"
  }

  // --- tools -----------------------------------------------------------------

  turnLeft() { this.turn(270) }

  turnRight() { this.turn(90) }

  turn(degrees) {
    if (!this.current) return
    this.current.rotate = (this.current.rotate + degrees) % 360
    this.current.crop = null
    this.current.texts = []
    this.touched(this.current)
  }

  toggleRemove() {
    if (!this.current) return
    this.current.removed = !this.current.removed
    this.thumb(this.current).classList.toggle("is-removed", this.current.removed)
    this.touched(this.current)
  }

  crop() { this.setMode(this.mode === "crop" ? "view" : "crop") }

  text() { this.setMode(this.mode === "text" ? "view" : "text") }

  clearCrop() {
    if (!this.current) return
    this.current.crop = null
    this.touched(this.current)
  }

  setMode(mode) {
    this.mode = mode
    this.draft = mode === "crop" && this.current?.crop ? { ...this.current.crop } : null
    this.point = null
    this.textBarTarget.hidden = mode !== "text"
    this.hintTarget.textContent = { crop: "Drag a box over the part to keep, or drag the box's edges, corners or middle to adjust it. Zoom out to reach every edge.",
                                    text: "Click where the text starts, type it, then Add text.",
                                    view: "" }[mode]
    this.stageTarget.classList.toggle("is-marking", mode !== "view")
    this.listTexts()
    this.drawStage()
  }

  touched(card) {
    this.changed = true
    this.drawThumb(card)
    if (card === this.current) this.setMode("view")
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
      let first = null
      for (let number = 1; number <= doc.numPages; number++) {
        const card = this.addCard(source, number, `${file.name} p${number}`)
        first ||= card
      }
      this.changed = true
      this.select(first)
    } catch (error) {
      console.error(error)
      pbAlert({ title: "Not added", message: `${file.name} could not be read as a PDF.` })
    }
  }

  // --- drawing ---------------------------------------------------------------

  async drawThumb(card) {
    const canvas = this.thumb(card)?.querySelector("canvas")
    if (!canvas) return
    const viewport = await this.render(card, canvas, THUMB_WIDTH)
    this.drawMarks(canvas.getContext("2d"), card, card.crop, viewport)
  }

  // --- zoom ------------------------------------------------------------------

  zoomIn() { this.setZoom((this.stageWidth || 600) * 1.25) }

  zoomOut() { this.setZoom((this.stageWidth || 600) / 1.25) }

  fitPage() { this.setZoom("page") }

  fitWidth() { this.setZoom("width") }

  setZoom(zoom) {
    this.zoom = zoom
    this.drawStage()
  }

  // The big page's width for the zoom: "page" fits the whole page in the
  // panel (the default, so a crop can reach every edge), "width" its width.
  stageWidthFor(plain) {
    const box = this.stageTarget.parentElement
    const room = { width: box.clientWidth - 24, height: box.clientHeight - 24 - (this.textBarTarget.hidden ? 0 : this.textBarTarget.offsetHeight) }
    const fitWidth = Math.max(200, room.width)
    const fitPage = Math.max(200, Math.min(fitWidth, room.height * (plain.width / plain.height)))
    const zoom = this.zoom || "page"
    const width = zoom === "page" ? fitPage : zoom === "width" ? fitWidth : Math.min(4000, Math.max(150, zoom))
    this.zoomLabelTarget.textContent = zoom === "page" ? "Fit page" : `${Math.round((width / plain.width) * 100)}%`
    return width
  }

  async drawStage() {
    if (!this.current) return
    this.showLabel()
    const card = this.current
    const viewport = await this.render(card, this.stageTarget, (plain) => this.stageWidthFor(plain))
    this.stageWidth = viewport.width
    if (card !== this.current) return
    this.stageViewport = viewport
    this.stageImage = this.stageTarget.getContext("2d").getImageData(0, 0, this.stageTarget.width, this.stageTarget.height)
    this.redrawStage()
  }

  redrawStage() {
    if (!this.stageImage) return
    const context = this.stageTarget.getContext("2d")
    context.putImageData(this.stageImage, 0, 0)
    this.drawMarks(context, this.current, this.mode === "crop" ? this.draft : this.current.crop, this.stageViewport)
    const { width, height } = this.stageTarget
    if (this.mode === "crop" && this.draft) {
      const box = [this.draft.left * width, this.draft.top * height, this.draft.right * width, this.draft.bottom * height]
      context.strokeStyle = "#16a34a"
      context.lineWidth = 2
      context.strokeRect(box[0], box[1], box[2] - box[0], box[3] - box[1])
      context.fillStyle = "#16a34a"
      const middleX = (box[0] + box[2]) / 2
      const middleY = (box[1] + box[3]) / 2
      ;[[box[0], box[1]], [middleX, box[1]], [box[2], box[1]], [box[2], middleY], [box[2], box[3]], [middleX, box[3]], [box[0], box[3]], [box[0], middleY]]
        .forEach(([x, y]) => context.fillRect(x - 5, y - 5, 10, 10))
    }
    if (this.mode === "text" && this.point) {
      context.fillStyle = "#dc2626"
      context.beginPath()
      context.arc(this.point.fx * width, this.point.fy * height, 5, 0, Math.PI * 2)
      context.fill()
    }
  }

  // Renders the page turned as the card says, +width+ wide (a number, or a
  // function of the page's own size); returns the viewport.
  async render(card, canvas, width) {
    const page = await this.sources[card.source].doc.getPage(card.page)
    const rotation = (page.rotate + card.rotate) % 360
    const plain = page.getViewport({ scale: 1, rotation })
    const wanted = typeof width === "function" ? width(plain) : width
    const viewport = page.getViewport({ scale: wanted / plain.width, rotation })
    canvas.width = Math.round(viewport.width)
    canvas.height = Math.round(viewport.height)
    await page.render({ canvasContext: canvas.getContext("2d"), viewport }).promise
    return viewport
  }

  // The crop (outside dimmed) and the text boxes, over a rendered page.
  drawMarks(context, card, shown, viewport) {
    const { width, height } = viewport
    if (shown) {
      context.fillStyle = "rgba(15, 23, 42, 0.55)"
      context.fillRect(0, 0, width, shown.top * height)
      context.fillRect(0, shown.bottom * height, width, (1 - shown.bottom) * height)
      context.fillRect(0, shown.top * height, shown.left * width, (shown.bottom - shown.top) * height)
      context.fillRect(shown.right * width, shown.top * height, (1 - shown.right) * width, (shown.bottom - shown.top) * height)
    }
    const crop = card.crop || { left: 0, top: 0, right: 1, bottom: 1 }
    context.fillStyle = "#000"
    card.texts.forEach((text) => {
      const size = text.size * viewport.scale
      context.font = `${size}px Helvetica, Arial, sans-serif`
      text.text.split(/\r?\n/).forEach((line, index) => {
        const x = (crop.left * width) + (text.x * (crop.right - crop.left) * width)
        const y = (crop.top * height) + (text.y * (crop.bottom - crop.top) * height) + (size * ((index * 1.2) + 1))
        context.fillText(line, x, y)
      })
    })
  }

  // --- crop and text on the big page -----------------------------------------

  // Where a pointer is on the big page, as fractions; clamped to the page
  // unless +free+.
  fraction(x, y, free = false) {
    const box = this.stageTarget.getBoundingClientRect()
    const fx = (x - box.left) / box.width
    const fy = (y - box.top) / box.height
    return free ? { fx, fy } : { fx: Math.min(1, Math.max(0, fx)), fy: Math.min(1, Math.max(0, fy)) }
  }

  // Which part of the crop box a point grabs: an edge or corner ("n", "se",
  // ...), "move" inside it, or null outside.
  grab(at) {
    const crop = this.draft
    if (!crop) return null
    const box = this.stageTarget.getBoundingClientRect()
    const near = (a, b, size) => Math.abs(a - b) * size <= EDGE
    const inX = at.fx >= crop.left - EDGE / box.width && at.fx <= crop.right + EDGE / box.width
    const inY = at.fy >= crop.top - EDGE / box.height && at.fy <= crop.bottom + EDGE / box.height
    if (!inX || !inY) return null
    const edge = (near(at.fy, crop.top, box.height) ? "n" : near(at.fy, crop.bottom, box.height) ? "s" : "") +
                 (near(at.fx, crop.left, box.width) ? "w" : near(at.fx, crop.right, box.width) ? "e" : "")
    return edge || "move"
  }

  pointerDown(event) {
    const at = this.fraction(event.clientX, event.clientY)
    if (this.mode === "crop") {
      this.stageTarget.setPointerCapture(event.pointerId)
      this.dragging = this.grab(at) || "new"
      this.anchor = at
      this.start = this.draft ? { ...this.draft } : null
      if (this.dragging === "new") this.draft = { left: at.fx, top: at.fy, right: at.fx, bottom: at.fy }
      this.last = { x: event.clientX, y: event.clientY }
    } else if (this.mode === "text") {
      this.point = at
      this.textInputTarget.focus()
    }
    this.redrawStage()
  }

  pointerMove(event) {
    if (this.mode !== "crop") return
    if (!this.dragging) {
      const part = this.grab(this.fraction(event.clientX, event.clientY))
      this.stageTarget.style.cursor = { move: "move", n: "ns-resize", s: "ns-resize", e: "ew-resize", w: "ew-resize",
                                        ne: "nesw-resize", sw: "nesw-resize", nw: "nwse-resize", se: "nwse-resize" }[part] || "crosshair"
      return
    }
    this.last = { x: event.clientX, y: event.clientY }
    this.dragTo(this.last)
    this.autoScroll()
  }

  dragTo({ x, y }) {
    const at = this.fraction(x, y)
    const kind = this.dragging
    if (kind === "new") {
      this.draft = { left: Math.min(this.anchor.fx, at.fx), right: Math.max(this.anchor.fx, at.fx),
                     top: Math.min(this.anchor.fy, at.fy), bottom: Math.max(this.anchor.fy, at.fy) }
    } else if (kind === "move") {
      const width = this.start.right - this.start.left
      const height = this.start.bottom - this.start.top
      const left = Math.min(1 - width, Math.max(0, this.start.left + at.fx - this.anchor.fx))
      const top = Math.min(1 - height, Math.max(0, this.start.top + at.fy - this.anchor.fy))
      this.draft = { left, top, right: left + width, bottom: top + height }
    } else {
      const crop = { ...this.start }
      if (kind.includes("n")) crop.top = Math.min(at.fy, crop.bottom - 0.02)
      if (kind.includes("s")) crop.bottom = Math.max(at.fy, crop.top + 0.02)
      if (kind.includes("w")) crop.left = Math.min(at.fx, crop.right - 0.02)
      if (kind.includes("e")) crop.right = Math.max(at.fx, crop.left + 0.02)
      this.draft = crop
    }
    this.redrawStage()
  }

  // Dragging near the panel's edge scrolls it, and the box follows.
  autoScroll() {
    if (this.scrolling) return
    const step = () => {
      if (!this.dragging || !this.last) { this.scrolling = false; return }
      const panel = this.stageTarget.parentElement
      const box = panel.getBoundingClientRect()
      const dx = this.last.x < box.left + SCROLL_EDGE ? -12 : this.last.x > box.right - SCROLL_EDGE ? 12 : 0
      const dy = this.last.y < box.top + SCROLL_EDGE ? -12 : this.last.y > box.bottom - SCROLL_EDGE ? 12 : 0
      if (!dx && !dy) { this.scrolling = false; return }
      const before = [panel.scrollLeft, panel.scrollTop]
      panel.scrollBy(dx, dy)
      if (panel.scrollLeft === before[0] && panel.scrollTop === before[1]) { this.scrolling = false; return }
      this.dragTo(this.last)
      requestAnimationFrame(step)
    }
    this.scrolling = true
    requestAnimationFrame(step)
  }

  pointerUp(event) {
    if (this.mode !== "crop" || !this.dragging) return
    if (event?.pointerId !== undefined && this.stageTarget.hasPointerCapture(event.pointerId)) this.stageTarget.releasePointerCapture(event.pointerId)
    this.dragging = null
    const crop = this.draft
    if (!crop || crop.right - crop.left < 0.02 || crop.bottom - crop.top < 0.02) {
      this.draft = this.current.crop ? { ...this.current.crop } : null
      return this.redrawStage()
    }
    const before = JSON.stringify(this.current.crop)
    this.current.crop = { ...crop }
    if (before !== JSON.stringify(this.current.crop)) {
      this.current.texts = []
      this.changed = true
      this.drawThumb(this.current)
    }
    this.redrawStage()
  }

  addText() {
    const text = this.textInputTarget.value.trim()
    if (!this.point || !text) return pbAlert({ title: "Text not added", message: "Click on the page where the text starts, then type it." })
    const crop = this.current.crop || { left: 0, top: 0, right: 1, bottom: 1 }
    const x = (this.point.fx - crop.left) / (crop.right - crop.left)
    const y = (this.point.fy - crop.top) / (crop.bottom - crop.top)
    if (x < 0 || x > 1 || y < 0 || y > 1) return pbAlert({ title: "Text not added", message: "Put the text inside the cropped page." })
    this.current.texts.push({ x, y, size: Number(this.textSizeTarget.value), text })
    this.textInputTarget.value = ""
    this.point = null
    this.changed = true
    this.drawThumb(this.current)
    this.listTexts()
    this.redrawStage()
  }

  listTexts() {
    const texts = this.mode === "text" ? this.current?.texts || [] : []
    this.textListTarget.replaceChildren(...texts.map((text, index) => {
      const item = document.createElement("li")
      item.textContent = text.text.replace(/\s+/g, " ").slice(0, 60)
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "btn compact ghost"
      remove.textContent = "Remove"
      remove.addEventListener("click", () => {
        this.current.texts.splice(index, 1)
        this.drawThumb(this.current)
        this.listTexts()
        this.redrawStage()
      })
      item.append(" ", remove)
      return item
    }))
  }

  // --- apply -----------------------------------------------------------------

  async apply(event) {
    event.preventDefault()
    const order = [...this.stripTarget.querySelectorAll(".aim-pdf-thumb")].map((element) => element.dataset.id)
    const pages = order.map((id) => this.cards.find((card) => card.id === id)).filter((card) => !card.removed)
      .map(({ source, page, rotate, crop, texts }) => ({ source, page, rotate, crop, texts }))
    if (pages.length === 0) return pbAlert({ title: "Nothing to keep", message: "Keep at least one page." })
    const ok = await pbConfirm({ title: "Apply changes", message: `Save the PDF with ${pages.length} page${pages.length === 1 ? "" : "s"}? The current one is kept as a version.`,
                                 confirmLabel: "Apply", confirmVariant: "approve" })
    if (!ok) return
    this.markReread(this.formTarget)
    this.pagesTarget.value = JSON.stringify(pages)
    const files = new DataTransfer()
    this.insertFiles.forEach((file) => files.items.add(file))
    this.insertsTarget.files = files.files
    this.formTarget.submit()
  }

  // Swap the whole PDF for the file just chosen, after a yes.
  async swap(event) {
    const input = event.target
    const file = input.files[0]
    if (!file) return
    const ok = await pbConfirm({ title: "Swap the whole PDF", message: `Replace this invoice's PDF with ${file.name}? The current one is kept as a version.`,
                                 confirmLabel: "Swap", confirmVariant: "approve" })
    if (!ok) { input.value = ""; return }
    this.markReread(input.form)
    input.form.submit()
  }

  markReread(form) {
    const field = form.querySelector("[data-reread]")
    if (field) field.value = this.hasRereadTarget && this.rereadTarget.checked ? "1" : "0"
  }

  loadPdfJs() {
    if (window.pdfjsLib) {
      window.pdfjsLib.GlobalWorkerOptions.workerSrc ||= PDF_WORKER_URL
      return Promise.resolve()
    }
    return new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = PDF_JS_URL
      script.onload = () => { window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDF_WORKER_URL; resolve() }
      script.onerror = reject
      document.head.appendChild(script)
    })
  }
}
