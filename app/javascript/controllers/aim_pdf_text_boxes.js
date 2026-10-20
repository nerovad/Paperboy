// Text boxes on the PDF editor's big page (#182), as in Word: each a live
// element over the page -- drag its top bar to move it, its corner to resize
// it, click in it to type; it stays editable after it is placed. Positions
// and sizes are fractions of the (cropped) page, which the layer covers, so
// Aim::PdfTextBox draws them where they are seen.
//
// A box: { x, y, w, h, size, text, bold, color, bg, border }.
export const COLORS = { black: "#000000", red: "#cc1a1a", blue: "#1a40bf" }
export const BACKGROUNDS = { none: "transparent", white: "#ffffff", yellow: "#fff266" }
export const DEFAULT_BOX = { w: 0.32, h: 0.05, size: 12, text: "", bold: false, color: "black", bg: "none", border: false }

const MIN_WIDTH = 0.05

export class TextBoxes {
  // layer: the element over the page; onChange(): a box changed;
  // onSelect(box | null): the selection changed.
  constructor(layer, { onChange, onSelect }) {
    this.layer = layer
    this.onChange = onChange
    this.onSelect = onSelect
    this.selected = null
    this.layer.addEventListener("pointerdown", (event) => {
      if (event.target === this.layer) this.select(null)
    })
  }

  // Draws +card+'s boxes; +scale+ turns points into pixels.
  show(card, scale) {
    this.card = card
    this.scale = scale
    this.layer.replaceChildren(...card.texts.map((box) => this.element(box)))
    if (!card.texts.includes(this.selected)) this.select(null)
    else this.mark()
  }

  // A new box with its top left at fractions +fx+, +fy+ of the layer, ready to type in.
  add(fx, fy) {
    const box = { ...DEFAULT_BOX, x: Math.min(fx, 1 - DEFAULT_BOX.w), y: Math.min(fy, 1 - DEFAULT_BOX.h) }
    this.card.texts.push(box)
    this.layer.appendChild(this.element(box))
    this.select(box)
    requestAnimationFrame(() => this.textOf(box)?.focus())
    return box
  }

  // Changes the selected box: { size, bold, color, bg, border }.
  update(change) {
    if (!this.selected) return
    Object.assign(this.selected, change)
    this.style(this.selected)
    this.measure(this.selected)
    this.onChange()
  }

  remove() {
    if (!this.selected) return
    this.card.texts.splice(this.card.texts.indexOf(this.selected), 1)
    this.selected.element?.remove()
    this.select(null)
    this.onChange()
  }

  select(box) {
    this.selected = box
    this.mark()
    this.onSelect(box)
  }

  mark() {
    this.layer.querySelectorAll(".aim-pdf-box").forEach((element) => element.classList.toggle("is-selected", element.box === this.selected))
  }

  textOf(box) { return box.element?.querySelector(".aim-pdf-box__text") }

  // --- one box ---------------------------------------------------------------

  element(box) {
    const element = document.createElement("div")
    element.className = "aim-pdf-box"
    element.box = box
    box.element = element
    element.innerHTML = `<div class="aim-pdf-box__bar" title="Drag to move"></div>
      <div class="aim-pdf-box__text" role="textbox" aria-multiline="true" aria-label="Text box" spellcheck="true"></div>
      <div class="aim-pdf-box__grip" title="Drag to resize"></div>`
    const text = element.querySelector(".aim-pdf-box__text")
    text.contentEditable = "plaintext-only"
    if (text.contentEditable !== "plaintext-only") text.contentEditable = "true"
    text.innerText = box.text
    text.addEventListener("focus", () => this.select(box))
    text.addEventListener("input", () => {
      box.text = text.innerText.replace(/\n$/, "")
      this.measure(box)
      this.onChange()
    })
    text.addEventListener("blur", () => { if (!box.text.trim() && this.card.texts.includes(box)) { this.selected = box; this.remove() } })
    element.addEventListener("pointerdown", (event) => { if (event.target !== text) event.preventDefault(); this.select(box) })
    this.drag(element.querySelector(".aim-pdf-box__bar"), box, (start, dx, dy) => {
      box.x = Math.min(1 - box.w, Math.max(0, start.x + dx))
      box.y = Math.min(1 - box.h, Math.max(0, start.y + dy))
    })
    this.drag(element.querySelector(".aim-pdf-box__grip"), box, (start, dx) => {
      box.w = Math.min(1 - box.x, Math.max(MIN_WIDTH, start.w + dx))
    })
    this.style(box)
    return element
  }

  style(box) {
    const element = box.element
    Object.assign(element.style, {
      left: `${box.x * 100}%`, top: `${box.y * 100}%`, width: `${box.w * 100}%`, minHeight: `${box.h * 100}%`,
      fontSize: `${box.size * this.scale}px`, fontWeight: box.bold ? "700" : "400",
      color: COLORS[box.color] || COLORS.black, background: BACKGROUNDS[box.bg] || BACKGROUNDS.none,
      outline: box.border ? `${Math.max(1, 0.75 * this.scale)}px solid #000` : ""
    })
  }

  // The box's height follows its text, as the PDF's does.
  measure(box) {
    const height = this.layer.getBoundingClientRect().height
    if (!height) return
    box.element.style.minHeight = ""
    box.h = Math.min(1 - box.y, Math.max(DEFAULT_BOX.h, box.element.offsetHeight / height))
    box.element.style.minHeight = `${box.h * 100}%`
  }

  // Dragging +handle+ moves or resizes +box+ by the pointer's travel, as
  // fractions of the layer.
  drag(handle, box, apply) {
    handle.addEventListener("pointerdown", (event) => {
      event.preventDefault()
      event.stopPropagation()
      this.select(box)
      handle.setPointerCapture(event.pointerId)
      const rect = this.layer.getBoundingClientRect()
      const start = { ...box, px: event.clientX, py: event.clientY }
      const move = (moved) => {
        apply(start, (moved.clientX - start.px) / rect.width, (moved.clientY - start.py) / rect.height)
        this.style(box)
      }
      const stop = () => {
        handle.removeEventListener("pointermove", move)
        handle.removeEventListener("pointerup", stop)
        handle.removeEventListener("pointercancel", stop)
        this.measure(box)
        this.onChange()
      }
      handle.addEventListener("pointermove", move)
      handle.addEventListener("pointerup", stop)
      handle.addEventListener("pointercancel", stop)
    })
  }
}

// Draws +box+ on a canvas (the page strip's thumbnails), wrapped as the PDF
// will be: +left+, +top+, +width+ and +height+ are the cropped page in pixels.
export function paintBox(context, box, { left, top, width, height }, scale) {
  const x = left + box.x * width
  const y = top + box.y * height
  const w = (box.w ?? 1 - box.x) * width
  const size = box.size * scale
  context.font = `${box.bold ? "bold " : ""}${size}px Helvetica, Arial, sans-serif`
  const lines = wrap(context, box.text, w - 4 * scale)
  const h = Math.max((box.h ?? 0) * height, lines.length * size * 1.2 + 4 * scale)
  if (box.bg && box.bg !== "none") { context.fillStyle = BACKGROUNDS[box.bg]; context.fillRect(x, y, w, h) }
  if (box.border) { context.strokeStyle = "#000"; context.lineWidth = Math.max(0.5, 0.75 * scale); context.strokeRect(x, y, w, h) }
  context.fillStyle = COLORS[box.color] || COLORS.black
  lines.forEach((line, index) => context.fillText(line, x + 2 * scale, y + 2 * scale + size * 0.8 + index * size * 1.2))
}

function wrap(context, text, room) {
  return text.split(/\r?\n/).flatMap((paragraph) => {
    const lines = [""]
    paragraph.split(/(?<= )/).forEach((word) => {
      const candidate = lines[lines.length - 1] + word
      if (!lines[lines.length - 1] || context.measureText(candidate.trimEnd()).width <= room) lines[lines.length - 1] = candidate
      else lines.push(word)
    })
    return lines.map((line) => line.trimEnd())
  })
}
