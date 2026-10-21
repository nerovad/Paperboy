import { Controller } from "@hotwired/stimulus"
import { loadPdfJs } from "pdf_js"
import { AREA_DEFAULTS, FONT_FAMILIES, PAD, anchorFor, fillRows, place } from "stamp_layout"

const MAX_PAGES = 30
const MAX_UPLOAD = 25 * 1024 * 1024
const WARNINGS = {
  shrunk: "Text made smaller to fit.",
  moved_inside: "Moved back inside the page.",
  too_big: "Too big for the page even at the smallest size: it cannot be saved like this.",
  covers_page: "Sits over printing on the page. A background keeps it readable, or move it to a clear spot."
}

// The stamp designer (#221). Every page of the chosen invoice, or of a PDF
// you upload, is drawn with pdf.js in a pane that scrolls and zooms on its
// own; each stamp area sits on the pages it prints on. Drag an area to move
// it (it keeps to the nearest corner or edge, so it stays put on other page
// sizes), drag its right edge to fix its width, and set it on the right.
// The live view fills fields as "Fill with" says (this invoice, samples, or
// long values) and is drawn with the same sums as the server
// (stamp_layout.js). Check has the server stamp the file for real and opens
// it in a new tab, in the browser's PDF viewer; nothing is saved. Save asks
// which invoices take the layout. The designer fills the window below its
// top, so only the pages and the settings scroll.
export default class extends Controller {
  static targets = ["pages", "scroller", "sample", "upload", "fileName", "fill", "list", "rows", "insert", "separator", "dateFormat",
    "control", "choice", "toggle", "shrink", "position", "warnings", "status", "zoomLabel", "body", "checkForm",
    "checkAreas", "checkShrink", "checkPosition", "checkFill", "checkInvoice", "checkFile", "form", "areasField",
    "shrinkField", "positionField", "saveModal", "saveButton", "restampField"]

  static values = { areas: Array, shrink: Number, position: String, samples: Object, worst: Object, formats: Object,
    sampleUrl: String, valuesUrl: String, previewUrl: String }

  connect() {
    this.areas = this.areasValue.map((area) => this.normalise(area))
    this.selected = 0
    this.zoom = 1
    this.pageShrink = this.shrinkValue || 100
    this.pagePosition = this.positionValue || "center"
    this.sheets = []
    this.fillMode = "invoice"
    this.invoiceValues = null
    this.showFill()
    this.showPanel()
    this.showPageSettings()
    this.fit()
    this.useInvoice()
    this.onResize = () => {
      clearTimeout(this.resizing)
      this.resizing = setTimeout(() => { this.fit(); this.renderPages() }, 150)
    }
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
  }

  // The three panels take the height left in whatever scrolls the page
  // (the layout's content area, or the window), so that never scrolls.
  fit() {
    if (!this.hasBodyTarget || window.innerWidth <= 1200) return
    const scroller = this.pageScroller()
    const view = scroller === document.scrollingElement ? window.innerHeight : scroller.clientHeight
    const viewTop = scroller === document.scrollingElement ? 0 : scroller.getBoundingClientRect().top
    const top = this.bodyTarget.getBoundingClientRect().top - viewTop + scroller.scrollTop
    let height = Math.max(320, view - top - 16)
    this.bodyTarget.style.height = `${height}px`
    const overflow = scroller.scrollHeight - view
    if (overflow > 0) this.bodyTarget.style.height = `${Math.max(320, height - overflow)}px`
  }

  // The AIM page scrolls inside its own area; elsewhere the window does.
  pageScroller() {
    return this.element.closest(".aim-page") || document.scrollingElement
  }

  // A clear background is kept as a colour at no opacity.
  normalise(area) {
    const merged = { ...AREA_DEFAULTS, ...area }
    if (!merged.background) Object.assign(merged, { background: "#ffffff", opacity: 0 })
    merged.rows = Array.isArray(merged.rows) ? merged.rows : []
    return merged
  }

  // The file

  useInvoice() {
    this.upload = null
    this.fileNameTarget.hidden = true
    if (this.hasUploadTarget) this.uploadTarget.value = ""
    if (!this.sampleTarget.value) return this.status("No invoice to preview on yet: upload a PDF.")
    const id = encodeURIComponent(this.sampleTarget.value)
    this.invoiceValues = null
    fetch(`${this.valuesUrlValue}?invoice_id=${id}`, { credentials: "same-origin", headers: { Accept: "application/json" } })
      .then((response) => (response.ok ? response.json() : null))
      .then((values) => { this.invoiceValues = values; this.draw() })
      .catch(() => {})
    this.showFill()
    this.open({ url: `${this.sampleUrlValue}?invoice_id=${id}`, withCredentials: true })
  }

  async useUpload() {
    const file = this.uploadTarget.files[0]
    if (!file) return
    if (file.size > MAX_UPLOAD) return this.status("That PDF is over 25 MB.")
    this.upload = file
    this.invoiceValues = null
    this.showFill()
    this.fileNameTarget.textContent = file.name
    this.fileNameTarget.hidden = false
    this.open({ data: await file.arrayBuffer() })
  }

  async open(source) {
    this.status("Loading…")
    try {
      const pdfjs = await loadPdfJs()
      this.pdf = await pdfjs.getDocument(source).promise
      this.pdfPages = []
      for (let number = 1; number <= Math.min(this.pdf.numPages, MAX_PAGES); number += 1) {
        this.pdfPages.push(await this.pdf.getPage(number))
      }
      await this.renderPages()
      this.status(this.pdf.numPages > MAX_PAGES ? `First ${MAX_PAGES} of ${this.pdf.numPages} pages.`
        : `${this.pdf.numPages} page${this.pdf.numPages === 1 ? "" : "s"}`)
    } catch (error) {
      this.status(`This PDF could not be shown: ${error.message}`)
    }
  }

  // The pages, at the zoom, each with its own layer of areas

  async renderPages() {
    if (!this.pdfPages) return
    const room = Math.max(200, this.scrollerTarget.clientWidth - 40)
    this.pagesTarget.replaceChildren()
    this.sheets = this.pdfPages.map((page, index) => this.sheet(page, index, room))
    for (const sheet of this.sheets) await this.paint(sheet)
    this.zoomLabelTarget.textContent = `${Math.round(this.zoom * 100)}%`
    this.draw()
  }

  sheet(page, index, room) {
    const plain = page.getViewport({ scale: 1 })
    const scale = (room / plain.width) * this.zoom
    const wrap = document.createElement("div")
    wrap.className = "stamp-designer__sheet"
    const canvas = document.createElement("canvas")
    canvas.className = "stamp-designer__page"
    canvas.width = Math.floor(plain.width * scale)
    canvas.height = Math.floor(plain.height * scale)
    const layer = document.createElement("div")
    layer.className = "stamp-designer__layer"
    Object.assign(layer.style, { width: `${canvas.width}px`, height: `${canvas.height}px` })
    const label = document.createElement("span")
    label.className = "stamp-designer__page-number"
    label.textContent = `Page ${index + 1}`
    wrap.append(canvas, layer, label)
    this.pagesTarget.append(wrap)
    return { page, index, canvas, layer, scale, width: plain.width, height: plain.height }
  }

  // The page drawn as the stamped copy will have it: shrunk and moved when
  // the layout says so, on white.
  async paint(sheet) {
    const shrink = this.pageShrink / 100
    const viewport = sheet.page.getViewport({ scale: sheet.scale * shrink })
    const drawn = document.createElement("canvas")
    drawn.width = Math.floor(viewport.width)
    drawn.height = Math.floor(viewport.height)
    await sheet.page.render({ canvasContext: drawn.getContext("2d"), viewport }).promise
    const context = sheet.canvas.getContext("2d", { willReadFrequently: true })
    context.fillStyle = "#ffffff"
    context.fillRect(0, 0, sheet.canvas.width, sheet.canvas.height)
    const spareX = sheet.canvas.width - drawn.width
    const spareY = sheet.canvas.height - drawn.height
    const x = { left: 0, right: spareX }[this.pagePosition] ?? spareX / 2
    const y = { top: 0, bottom: spareY }[this.pagePosition] ?? spareY / 2
    context.drawImage(drawn, x, y)
  }

  // What the fields are filled with, the same in the live view and Check:
  // exactly what the invoice would print, samples, or every field at its
  // longest. An uploaded PDF has no invoice: samples.
  values() {
    if (this.fillMode === "worst") return this.worstValue
    if (this.fillMode === "invoice" && !this.upload) return this.invoiceValues || {}
    return this.samplesValue
  }

  setFill(event) {
    this.fillMode = event.currentTarget.dataset.value
    this.showFill()
    this.draw()
  }

  showFill() {
    this.fillTargets.forEach((button) => {
      button.classList.toggle("active", button.dataset.value === this.fillMode)
      if (button.dataset.value === "invoice") button.disabled = Boolean(this.upload)
    })
  }

  onPage(area, index) {
    if (area.pages === "first") return index === 0
    if (area.pages === "last") return index === this.sheets.length - 1
    return true
  }

  draw() {
    this.placed = this.sheets.map((sheet) => {
      sheet.layer.replaceChildren()
      return this.areas.map((area, index) => {
        if (!this.onPage(area, sheet.index)) return null
        const lines = fillRows(area.rows, this.values(), this.formatsValue)
        const placed = place(area, lines.length ? lines : ["(nothing to print)"], sheet.width, sheet.height)
        if (this.inkUnder(sheet, placed)) placed.warnings.push("covers_page")
        sheet.layer.append(this.areaElement(sheet, area, placed, index, !lines.length))
        return placed
      })
    })
    this.showList()
    this.showWarnings()
  }

  areaElement(sheet, area, placed, index, empty) {
    const box = document.createElement("div")
    box.className = `stamp-area${index === this.selected ? " is-selected" : ""}${empty ? " is-empty" : ""}`
    const scale = sheet.scale
    const top = sheet.height - placed.bottom - placed.height
    Object.assign(box.style, {
      left: `${placed.left * scale}px`, top: `${top * scale}px`, width: `${placed.width * scale}px`,
      height: `${placed.height * scale}px`, padding: `${PAD * scale}px`, color: area.color, textAlign: area.align,
      fontFamily: FONT_FAMILIES[area.font] || FONT_FAMILIES.helvetica, fontWeight: area.bold ? "bold" : "normal",
      fontStyle: area.italic ? "italic" : "normal", fontSize: `${placed.size * scale}px`,
      lineHeight: `${placed.size * area.leading * scale}px`, transform: `rotate(${placed.rotation}deg)`,
      background: Number(area.opacity) > 0 ? this.rgba(area.background, area.opacity) : "transparent",
      border: area.border ? `${Math.max(1, 0.5 * scale)}px solid ${area.color}` : ""
    })
    box.title = `${area.name}: drag to move`
    placed.lines.forEach((line) => {
      const row = document.createElement("div")
      row.textContent = line || " "
      box.append(row)
    })
    const grip = document.createElement("span")
    grip.className = "stamp-area__grip"
    grip.title = "Drag to set the width"
    box.append(grip)
    box.addEventListener("pointerdown", (event) => this.startDrag(event, sheet, index, event.target === grip))
    return box
  }

  // Whether the page has printing under an area: dark pixels on the drawn
  // page, so a scan counts as much as typed text.
  inkUnder(sheet, placed) {
    const { left, bottom, width, height } = placed.outer
    const x = Math.max(0, Math.floor(left * sheet.scale))
    const y = Math.max(0, Math.floor((sheet.height - bottom - height) * sheet.scale))
    const w = Math.min(sheet.canvas.width - x, Math.ceil(width * sheet.scale))
    const h = Math.min(sheet.canvas.height - y, Math.ceil(height * sheet.scale))
    if (w < 1 || h < 1) return false
    const { data } = sheet.canvas.getContext("2d", { willReadFrequently: true }).getImageData(x, y, w, h)
    let dark = 0
    for (let at = 0; at < data.length; at += 4) {
      if ((data[at] * 0.3) + (data[at + 1] * 0.59) + (data[at + 2] * 0.11) < 160) dark += 1
    }
    return dark / (w * h) > 0.004
  }

  // Dragging. Selecting marks the area without redrawing, so the element
  // under the pointer stays while it moves.
  startDrag(event, sheet, index, resizing) {
    event.preventDefault()
    this.selected = index
    this.pagesTarget.querySelectorAll(".stamp-area").forEach((element) => element.classList.remove("is-selected"))
    event.currentTarget.classList.add("is-selected")
    this.showList()
    this.showPanel()
    const placed = this.placed[sheet.index][index]
    const start = { x: event.clientX, y: event.clientY, outer: { ...placed.outer }, width: placed.width }
    const move = (moved) => {
      const dx = (moved.clientX - start.x) / sheet.scale
      const dy = (moved.clientY - start.y) / sheet.scale
      if (resizing) {
        this.areas[index].width = Math.max(20, Math.round(start.width + dx))
      } else {
        const outer = { ...start.outer, left: start.outer.left + dx, bottom: start.outer.bottom - dy }
        Object.assign(this.areas[index], anchorFor(outer, sheet.width, sheet.height))
      }
      this.draw()
    }
    const stop = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", stop)
      this.showPanel()
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", stop)
  }

  // Zoom

  zoomIn() { this.setZoom(Math.min(4, this.zoom * 1.25)) }

  zoomOut() { this.setZoom(Math.max(0.25, this.zoom / 1.25)) }

  zoomFit() { this.setZoom(1) }

  setZoom(zoom) {
    this.zoom = Math.round(zoom * 100) / 100
    this.renderPages()
  }

  // The areas

  select(index) {
    this.selected = index
    this.draw()
    this.showPanel()
  }

  pick(event) {
    this.select(Number(event.currentTarget.dataset.index))
  }

  addArea() {
    this.areas.push(this.normalise({ name: `Stamp ${this.areas.length + 1}`, rows: ["{approver}"], anchor: "top_right",
      x: 24, y: 24, size: 9, align: "left", border: true }))
    this.select(this.areas.length - 1)
  }

  removeArea() {
    if (this.areas.length < 2) return this.status("A stamp needs at least one area.")
    this.areas.splice(this.selected, 1)
    this.select(Math.max(0, this.selected - 1))
  }

  showList() {
    this.listTarget.replaceChildren(...this.areas.map((area, index) => {
      const card = document.createElement("button")
      card.type = "button"
      card.className = `stamp-designer__area${index === this.selected ? " is-selected" : ""}`
      card.dataset.index = index
      card.dataset.action = "stamp-designer#pick"
      const name = document.createElement("strong")
      name.textContent = area.name || `Stamp ${index + 1}`
      const first = document.createElement("span")
      first.textContent = area.rows.find((row) => row.trim()) || "No text yet"
      const tags = [area.pages === "first" ? "First page" : area.pages === "last" ? "Last page" : null,
        Number(area.rotation) ? `Turned ${area.rotation}°` : null].filter(Boolean)
      const meta = document.createElement("small")
      meta.textContent = tags.join(" · ")
      card.append(name, first, meta)
      return card
    }))
  }

  // The settings panel

  showPanel() {
    const area = this.areas[this.selected]
    if (!area) return
    this.controlTargets.forEach((control) => {
      const key = control.dataset.key
      if (key === "rows") control.value = area.rows.join("\n")
      else if (key === "width") control.value = area.width || ""
      else control.value = area[key] ?? ""
    })
    this.choiceTargets.forEach((button) => {
      button.classList.toggle("active", String(area[button.dataset.key]) === button.dataset.value)
    })
    this.toggleTargets.forEach((button) => button.classList.toggle("active", Boolean(area[button.dataset.key])))
  }

  edit(event) {
    const area = this.areas[this.selected]
    const control = event.currentTarget
    const key = control.dataset.key
    const number = (value, fallback) => (value !== "" && Number.isFinite(Number(value)) ? Number(value) : fallback)
    switch (key) {
      case "rows": area.rows = control.value.split("\n"); break
      case "width": area.width = control.value === "" ? null : Math.max(20, number(control.value, 150)); break
      case "size": area.size = Math.min(36, Math.max(6, number(control.value, 7))); break
      case "x": case "y": area[key] = number(control.value, 0); break
      case "rotation": case "opacity": case "leading": area[key] = number(control.value, AREA_DEFAULTS[key]); break
      default: area[key] = control.value
    }
    this.draw()
  }

  choose(event) {
    const { key, value } = event.currentTarget.dataset
    this.areas[this.selected][key] = value
    this.draw()
    this.showPanel()
  }

  toggle(event) {
    const { key } = event.currentTarget.dataset
    const area = this.areas[this.selected]
    area[key] = !area[key]
    this.draw()
    this.showPanel()
  }

  // A separator goes in at the cursor as "[ _ ]": it prints only when the
  // field after it has a value.
  insertSeparator() {
    const separator = this.separatorTarget.value
    this.separatorTarget.value = ""
    if (separator) this.insertText(`[${separator}]`)
  }

  // A field goes in at the cursor; a date takes the format picked.
  insertField() {
    const option = this.insertTarget.selectedOptions[0]
    const field = this.insertTarget.value
    if (!field) return
    const dated = ["date", "datetime"].includes(option.dataset.kind)
    const format = dated ? this.dateFormatTarget.value : ""
    this.insertTarget.value = ""
    this.insertText(format ? `{${field}|${format}}` : `{${field}}`)
  }

  insertText(token) {
    const rows = this.rowsTarget
    const at = rows.selectionStart ?? rows.value.length
    rows.value = rows.value.slice(0, at) + token + rows.value.slice(rows.selectionEnd ?? at)
    rows.focus()
    rows.setSelectionRange(at + token.length, at + token.length)
    rows.dispatchEvent(new Event("input"))
  }

  showWarnings() {
    const found = new Set()
    this.placed?.forEach((page) => page[this.selected]?.warnings.forEach((key) => found.add(key)))
    const list = [...found].map((key) => WARNINGS[key])
    this.warningsTarget.textContent = list.join(" ")
    this.warningsTarget.hidden = list.length === 0
  }

  // Making room on the page

  setShrink() {
    this.pageShrink = Number(this.shrinkTarget.value)
    this.renderPages()
  }

  setPosition(event) {
    this.pagePosition = event.currentTarget.dataset.value
    this.showPageSettings()
    this.renderPages()
  }

  showPageSettings() {
    this.shrinkTarget.value = String(this.pageShrink)
    this.positionTargets.forEach((button) => button.classList.toggle("active", button.dataset.value === this.pagePosition))
  }

  // The server's check: the file stamped for real, opened in a new tab in
  // the browser's PDF viewer. Nothing is saved.
  check() {
    this.checkAreasTarget.value = JSON.stringify(this.areas)
    this.checkShrinkTarget.value = this.pageShrink
    this.checkPositionTarget.value = this.pagePosition
    this.checkFillTarget.value = this.upload && this.fillMode === "invoice" ? "samples" : this.fillMode
    const files = new DataTransfer()
    if (this.upload) files.items.add(this.upload)
    this.checkFileTarget.files = files.files
    this.checkInvoiceTarget.value = this.upload ? "" : this.sampleTarget.value
    this.checkFormTarget.submit()
    this.status("The check opened in a new tab.")
  }

  // Saving

  openSave() {
    this.restampFieldTargets.forEach((radio) => { radio.checked = false })
    this.saveButtonTarget.disabled = true
    this.saveModalTarget.hidden = false
  }

  closeSave() {
    this.saveModalTarget.hidden = true
  }

  chooseRestamp() {
    this.saveButtonTarget.disabled = !this.restampFieldTargets.some((radio) => radio.checked)
  }

  save() {
    this.areasFieldTarget.value = JSON.stringify(this.areas.map((area) => ({ ...area, rows: area.rows.filter((row) => row !== "") })))
    this.shrinkFieldTarget.value = this.pageShrink
    this.positionFieldTarget.value = this.pagePosition
    this.formTarget.requestSubmit()
  }

  status(message) {
    this.statusTarget.textContent = message
  }

  rgba(hex, opacity) {
    const [r, g, b] = (hex || "#ffffff").slice(1).match(/../g).map((pair) => parseInt(pair, 16))
    return `rgba(${r}, ${g}, ${b}, ${opacity})`
  }
}
