import { Controller } from "@hotwired/stimulus"
import { loadPdfJs } from "pdf_js"
import { AREA_DEFAULTS, FONT_FAMILIES, PAD, anchorFor, fillRows, place } from "stamp_layout"

// The stamp designer (#221). A sample invoice's first page is drawn with
// pdf.js and each stamp area sits over it where it will print: drag an area
// to move it (it keeps to the nearest corner or edge, so it stays there on
// other page sizes), pull its right edge to fix its width, and set its text
// and look in the panel. Fields go in as chips ({approver}). The live view
// fills them with sample values ("Worst case": the longest recent ones);
// "Check on this invoice" has the server stamp the chosen invoice with the
// real stamp code and shows every page, writing nothing. Save asks which
// invoices take the new layout.
export default class extends Controller {
  static targets = ["page", "layer", "sample", "worstCase", "list", "rows", "warnings", "preview", "previewNote",
    "form", "areasField", "noteField", "restampField", "saveModal", "saveButton", "dateFormat", "control", "status"]

  static values = { areas: Array, samples: Object, worst: Object, formats: Object, sampleUrl: String, previewUrl: String }

  connect() {
    this.areas = this.areasValue.map((area) => ({ ...AREA_DEFAULTS, ...area }))
    this.selected = 0
    this.loadSample()
    this.showPanel()
    this.resize = () => this.renderPage()
    window.addEventListener("resize", this.resize)
  }

  disconnect() {
    window.removeEventListener("resize", this.resize)
  }

  // The page

  async loadSample() {
    if (!this.hasSampleTarget || !this.sampleTarget.value) return this.status("No invoice to lay the stamp on yet.")
    this.status("Loading the page…")
    try {
      const pdfjs = await loadPdfJs()
      const url = `${this.sampleUrlValue}?invoice_id=${encodeURIComponent(this.sampleTarget.value)}`
      this.pdf = await pdfjs.getDocument({ url, withCredentials: true }).promise
      this.pdfPage = await this.pdf.getPage(1)
      await this.renderPage()
      this.status(this.pdf.numPages > 1 ? `Page 1 of ${this.pdf.numPages} shown. Pages decides where each area prints.` : "")
    } catch (error) {
      this.status(`The page could not be shown: ${error.message}`)
    }
  }

  async renderPage() {
    if (!this.pdfPage) return
    const plain = this.pdfPage.getViewport({ scale: 1 })
    this.pageWidth = plain.width
    this.pageHeight = plain.height
    const room = this.pageTarget.parentElement.clientWidth || 700
    this.scale = room / plain.width
    const viewport = this.pdfPage.getViewport({ scale: this.scale })
    const canvas = this.pageTarget
    canvas.width = Math.floor(viewport.width)
    canvas.height = Math.floor(viewport.height)
    this.layerTarget.style.width = `${canvas.width}px`
    this.layerTarget.style.height = `${canvas.height}px`
    this.rendering?.cancel()
    this.rendering = this.pdfPage.render({ canvasContext: canvas.getContext("2d"), viewport })
    try { await this.rendering.promise } catch { return }
    this.draw()
  }

  values() {
    return this.hasWorstCaseTarget && this.worstCaseTarget.checked ? this.worstValue : this.samplesValue
  }

  // The areas

  draw() {
    if (!this.scale) return
    this.layerTarget.replaceChildren()
    this.placed = this.areas.map((area, index) => {
      const lines = fillRows(area.rows, this.values(), this.formatsValue)
      const placed = place(area, lines.length ? lines : ["(nothing to print)"], this.pageWidth, this.pageHeight)
      if (this.inkUnder(placed)) placed.warnings.push("covers_page")
      this.layerTarget.append(this.element(area, placed, index, !lines.length))
      return placed
    })
    this.showList()
    this.showWarnings()
  }

  element(area, placed, index, empty) {
    const box = document.createElement("div")
    box.className = `stamp-area${index === this.selected ? " is-selected" : ""}${empty ? " is-empty" : ""}`
    if (area.pages !== "all") box.classList.add("is-some-pages")
    Object.assign(box.style, {
      left: `${placed.left * this.scale}px`, top: `${(this.pageHeight - placed.bottom - placed.height) * this.scale}px`,
      width: `${placed.width * this.scale}px`, height: `${placed.height * this.scale}px`,
      padding: `${PAD * this.scale}px`, color: area.color, textAlign: area.align,
      fontFamily: FONT_FAMILIES[area.font] || FONT_FAMILIES.helvetica, fontWeight: area.bold ? "bold" : "normal",
      fontStyle: area.italic ? "italic" : "normal", fontSize: `${placed.size * this.scale}px`,
      lineHeight: `${placed.size * area.leading * this.scale}px`,
      background: area.background ? this.rgba(area.background, area.opacity) : "transparent",
      border: area.border ? `${Math.max(1, 0.5 * this.scale)}px solid ${area.color}` : ""
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
    box.addEventListener("pointerdown", (event) => this.startDrag(event, index, event.target === grip))
    return box
  }

  // Selecting marks the area without redrawing, so the element under the
  // pointer stays while it is dragged.
  startDrag(event, index, resizing) {
    event.preventDefault()
    this.selected = index
    this.layerTarget.querySelectorAll(".stamp-area").forEach((element, at) => element.classList.toggle("is-selected", at === index))
    this.showList()
    this.showPanel()
    const start = { x: event.clientX, y: event.clientY, rect: { ...this.placed[index] } }
    const move = (moved) => {
      const dx = (moved.clientX - start.x) / this.scale
      const dy = (moved.clientY - start.y) / this.scale
      const rect = { ...start.rect }
      if (resizing) {
        rect.width = Math.max(20, start.rect.width + dx)
        this.areas[index].width = Math.round(rect.width)
      } else {
        rect.left += dx
        rect.bottom -= dy
      }
      Object.assign(this.areas[index], anchorFor(rect, this.pageWidth, this.pageHeight))
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

  // Whether the page has printing under an area: dark pixels on the drawn
  // page, so a scan counts as much as typed text.
  inkUnder(placed) {
    const context = this.pageTarget.getContext("2d", { willReadFrequently: true })
    const x = Math.max(0, Math.floor(placed.left * this.scale))
    const y = Math.max(0, Math.floor((this.pageHeight - placed.bottom - placed.height) * this.scale))
    const width = Math.min(this.pageTarget.width - x, Math.ceil(placed.width * this.scale))
    const height = Math.min(this.pageTarget.height - y, Math.ceil(placed.height * this.scale))
    if (width < 1 || height < 1) return false
    const { data } = context.getImageData(x, y, width, height)
    let dark = 0
    for (let at = 0; at < data.length; at += 4) {
      if ((data[at] * 0.3) + (data[at + 1] * 0.59) + (data[at + 2] * 0.11) < 160) dark += 1
    }
    return dark / (width * height) > 0.004
  }

  select(index) {
    this.selected = index
    this.draw()
    this.showPanel()
  }

  pick(event) {
    this.select(Number(event.currentTarget.dataset.index))
  }

  addArea() {
    this.areas.push({ ...AREA_DEFAULTS, name: `Stamp ${this.areas.length + 1}`, rows: ["{approver}"], anchor: "top_right",
      x: 24, y: 24, size: 9, align: "left", border: true })
    this.select(this.areas.length - 1)
  }

  removeArea() {
    if (this.areas.length < 2) return this.status("A stamp needs at least one area.")
    this.areas.splice(this.selected, 1)
    this.select(Math.max(0, this.selected - 1))
  }

  // The panel

  showList() {
    if (!this.hasListTarget) return
    this.listTarget.replaceChildren(...this.areas.map((area, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = `btn compact${index === this.selected ? " active" : ""}`
      button.textContent = area.name || `Stamp ${index + 1}`
      button.dataset.index = index
      button.dataset.action = "stamp-designer#pick"
      return button
    }))
  }

  showPanel() {
    const area = this.areas[this.selected]
    if (!area) return
    this.controlTargets.forEach((control) => {
      const key = control.dataset.key
      if (key === "rows") control.value = area.rows.join("\n")
      else if (key === "background_on") control.checked = Boolean(area.background)
      else if (key === "auto_width") control.checked = !area.width
      else if (control.type === "checkbox") control.checked = Boolean(area[key])
      else if (key === "background") control.value = area.background || "#ffffff"
      else if (key === "width") control.value = area.width || ""
      else control.value = area[key] ?? ""
    })
  }

  edit(event) {
    const area = this.areas[this.selected]
    const control = event.currentTarget
    const key = control.dataset.key
    const number = (value, fallback) => (Number.isFinite(Number(value)) && value !== "" ? Number(value) : fallback)
    switch (key) {
      case "rows": area.rows = control.value.split("\n"); break
      case "background_on": area.background = control.checked ? (this.backgroundControl()?.value || "#ffffff") : null; break
      case "background": if (area.background !== null) area.background = control.value; break
      case "auto_width": area.width = control.checked ? null : Math.round(this.placed[this.selected]?.width || 150); break
      case "width": area.width = control.value === "" ? null : Math.max(20, number(control.value, 150)); break
      case "size": area.size = Math.min(36, Math.max(6, number(control.value, 7))); break
      case "x": case "y": area[key] = number(control.value, 0); break
      case "opacity": case "leading": area[key] = number(control.value, AREA_DEFAULTS[key]); break
      default: area[key] = control.type === "checkbox" ? control.checked : control.value
    }
    this.draw()
    if (["auto_width", "background_on"].includes(key)) this.showPanel()
  }

  backgroundControl() {
    return this.controlTargets.find((control) => control.dataset.key === "background")
  }

  // A chip puts its field in at the cursor; a date takes the format picked.
  insertField(event) {
    const { field, kind } = event.currentTarget.dataset
    const format = (kind === "date" || kind === "datetime") && this.hasDateFormatTarget ? this.dateFormatTarget.value : ""
    const token = format ? `{${field}|${format}}` : `{${field}}`
    const rows = this.rowsTarget
    const at = rows.selectionStart ?? rows.value.length
    rows.value = rows.value.slice(0, at) + token + rows.value.slice(rows.selectionEnd ?? at)
    rows.focus()
    rows.setSelectionRange(at + token.length, at + token.length)
    rows.dispatchEvent(new Event("input"))
  }

  showWarnings() {
    if (!this.hasWarningsTarget) return
    const messages = { shrunk: "Text made smaller to fit.", moved_inside: "Moved back inside the page.",
      too_big: "Too big for the page even at the smallest size: it cannot be saved like this.",
      covers_page: "Sits over printing on this page. A background keeps the stamp readable; or move it to a clear spot." }
    const list = (this.placed?.[this.selected]?.warnings || []).map((key) => messages[key])
    this.warningsTarget.textContent = list.join(" ")
    this.warningsTarget.hidden = list.length === 0
  }

  // The server's check: the chosen invoice, really stamped, nothing saved.
  async check() {
    if (!this.sampleTarget.value) return
    this.previewNoteTarget.textContent = "Stamping the invoice…"
    this.previewTarget.replaceChildren()
    const body = new FormData()
    body.append("areas", JSON.stringify(this.areas))
    body.append("invoice_id", this.sampleTarget.value)
    body.append("worst_case", this.hasWorstCaseTarget && this.worstCaseTarget.checked ? "1" : "0")
    body.append("authenticity_token", document.querySelector('meta[name="csrf-token"]')?.content || "")
    const response = await fetch(this.previewUrlValue, { method: "POST", body, credentials: "same-origin" })
    const warnings = response.headers.get("X-Stamp-Warnings") || ""
    if (!response.ok) {
      this.previewNoteTarget.textContent = warnings || "The invoice could not be stamped."
      return
    }
    const pdfjs = await loadPdfJs()
    const pdf = await pdfjs.getDocument({ data: await response.arrayBuffer() }).promise
    for (let number = 1; number <= Math.min(pdf.numPages, 6); number += 1) {
      const page = await pdf.getPage(number)
      const plain = page.getViewport({ scale: 1 })
      const viewport = page.getViewport({ scale: 340 / plain.width })
      const canvas = document.createElement("canvas")
      canvas.width = Math.floor(viewport.width)
      canvas.height = Math.floor(viewport.height)
      canvas.className = "stamp-designer__preview-page"
      this.previewTarget.append(canvas)
      await page.render({ canvasContext: canvas.getContext("2d"), viewport }).promise
    }
    const more = pdf.numPages > 6 ? ` First 6 of ${pdf.numPages} pages shown.` : ""
    this.previewNoteTarget.textContent = (warnings ? `Check: ${warnings}.` : "Stamped without needing any safety net.") + more
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
    this.formTarget.requestSubmit()
  }

  status(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  rgba(hex, opacity) {
    const [r, g, b] = hex.slice(1).match(/../g).map((pair) => parseInt(pair, 16))
    return `rgba(${r}, ${g}, ${b}, ${opacity})`
  }
}
