// The stamp designer's sums (#221), the same as the server's: how a stamp
// area's rows are filled (Paperboy::Pdf::StampTemplate) and where the area
// lands on a page (Paperboy::Pdf::StampBox#place). The designer draws with
// these while you drag; "Check on this invoice" asks the server, whose
// stamp is the one written.
//
// Units are PDF points on the page as seen, origin bottom left.

export const PAD = 2
export const MARGIN = 4
export const MIN_SIZE = 6
export const ASCENT = 0.8

export const FONT_FAMILIES = {
  helvetica: "Helvetica, Arial, sans-serif",
  times: "'Times New Roman', Times, serif",
  courier: "'Courier New', Courier, monospace"
}

export const AREA_DEFAULTS = {
  name: "Stamp", rows: [], anchor: "bottom_right", x: 8, y: 8, width: null, align: "right", font: "helvetica",
  bold: false, italic: false, size: 7, color: "#000000", leading: 8.5 / 7, background: "#ffffff", opacity: 1,
  border: false, pages: "all"
}

const TOKEN = /\{([a-z][a-z0-9_]*)(?:\|([^{}]*))?\}/g
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
  "November", "December"]
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

// values: { name: { kind: "date"|"datetime"|"money"|"text", value } }; the
// date kinds' values are "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS", read as
// written (no time zone sums).
export function fillRows(rows, values, formats = {}) {
  return rows.map((row) => fillRow(row, values, formats)).filter((row) => !row.skip).map((row) => row.text)
}

export function fillRow(row, values, formats = {}) {
  let fields = 0
  let filled = 0
  const text = String(row).replace(TOKEN, (_, name, format) => {
    fields += 1
    const shown = render(values[name], format || formats[name])
    if (shown) filled += 1
    return shown
  })
  return { text, skip: fields > 0 && filled === 0 }
}

function render(field, format) {
  if (!field || field.value === null || field.value === undefined || field.value === "") return ""
  if (field.kind === "date" || field.kind === "datetime") return strftime(parseLocal(field.value), format || "%m/%d/%Y")
  if (field.kind === "money") {
    const amount = Number(field.value)
    if (format === "plain") return amount.toFixed(2)
    const shown = Math.abs(amount).toLocaleString("en-US", { style: "currency", currency: "USD" })
    return amount < 0 ? `-${shown}` : shown
  }
  const text = String(field.value)
  if (format === "upper") return text.toUpperCase()
  if (format === "lower") return text.toLowerCase()
  return text
}

function parseLocal(value) {
  const [date, time = "00:00:00"] = String(value).split("T")
  const [y, m, d] = date.split("-").map(Number)
  const [hh, mm, ss] = time.split(":").map((part) => parseInt(part, 10) || 0)
  return new Date(y, m - 1, d, hh, mm, ss)
}

const pad = (n, width = 2) => String(n).padStart(width, "0")

// The strftime codes people use on a stamp; any other is left as typed.
export function strftime(date, format) {
  return format.replace(/%(-?)([a-zA-Z%])/g, (code, flag, letter) => {
    const plain = flag === "-"
    const two = (n) => (plain ? String(n) : pad(n))
    switch (letter) {
      case "Y": return String(date.getFullYear())
      case "y": return pad(date.getFullYear() % 100)
      case "m": return two(date.getMonth() + 1)
      case "d": return two(date.getDate())
      case "e": return String(date.getDate()).padStart(2, " ")
      case "H": return two(date.getHours())
      case "I": return two(((date.getHours() + 11) % 12) + 1)
      case "M": return two(date.getMinutes())
      case "S": return two(date.getSeconds())
      case "p": return date.getHours() < 12 ? "AM" : "PM"
      case "B": return MONTHS[date.getMonth()]
      case "b": return MONTHS[date.getMonth()].slice(0, 3)
      case "A": return DAYS[date.getDay()]
      case "a": return DAYS[date.getDay()].slice(0, 3)
      case "%": return "%"
      default: return code
    }
  })
}

// A measurer in points for an area's face, from a canvas.
export function measurer(area) {
  const context = document.createElement("canvas").getContext("2d")
  return (text, size) => {
    context.font = `${area.italic ? "italic " : ""}${area.bold ? "bold " : ""}${size}px ${FONT_FAMILIES[area.font] || FONT_FAMILIES.helvetica}`
    return context.measureText(text).width
  }
}

// Where an area with +lines+ lands on a page +pageWidth+ by +pageHeight+:
// { left, bottom, width, height, size, lines, warnings }.
export function place(area, lines, pageWidth, pageHeight, measure = measurer(area)) {
  const warnings = []
  const roomWidth = pageWidth - (MARGIN * 2)
  const roomHeight = pageHeight - (MARGIN * 2)
  let size = area.size
  for (;;) {
    const limit = Math.min(area.width || Infinity, roomWidth) - (PAD * 2)
    const wrapped = lines.flatMap((line) => wrap(line, limit, (text) => measure(text, size)))
    const inner = area.width ? limit : Math.min(Math.max(0, ...wrapped.map((line) => measure(line, size))), limit)
    const width = inner + (PAD * 2)
    const height = (wrapped.length * size * area.leading) + (PAD * 2)
    if (height <= roomHeight || size <= MIN_SIZE) {
      if (size < area.size) warnings.push("shrunk")
      if (height > roomHeight) warnings.push("too_big")
      const [left, bottom] = anchored(area, pageWidth, pageHeight, width, height)
      const keptLeft = keepInside(left, pageWidth, width)
      const keptBottom = keepInside(bottom, pageHeight, height)
      if (Math.abs(keptLeft - left) > 0.01 || Math.abs(keptBottom - bottom) > 0.01) warnings.push("moved_inside")
      return { left: keptLeft, bottom: keptBottom, width, height, size, lines: wrapped, warnings }
    }
    size = Math.max(size - 0.5, MIN_SIZE)
  }
}

function wrap(line, limit, width) {
  if (width(line) <= limit) return [line]
  const out = [""]
  for (const word of line.split(/(\s+)/)) {
    const candidate = out[out.length - 1] + word
    if (out[out.length - 1] === "" || width(candidate.trimEnd()) <= limit) out[out.length - 1] = candidate
    else out.push(word.trimStart())
    if (width(out[out.length - 1].trimEnd()) > limit) out.push(...breakWord(out.pop(), limit, width))
  }
  return out.map((piece) => piece.trimEnd())
}

function breakWord(word, limit, width) {
  const pieces = [""]
  for (const char of word) {
    if (pieces[pieces.length - 1] !== "" && width(pieces[pieces.length - 1] + char) > limit) pieces.push("")
    pieces[pieces.length - 1] += char
  }
  return pieces
}

function split(anchor) {
  if (anchor === "center") return ["middle", "center"]
  return anchor.split("_")
}

function anchored(area, pageWidth, pageHeight, width, height) {
  const [vertical, horizontal] = split(area.anchor)
  const left = horizontal === "left" ? area.x : horizontal === "right" ? pageWidth - area.x - width
    : ((pageWidth - width) / 2) + area.x
  const bottom = vertical === "bottom" ? area.y : vertical === "top" ? pageHeight - area.y - height
    : ((pageHeight - height) / 2) + area.y
  return [left, bottom]
}

function keepInside(start, extent, size) {
  if (size > extent - (MARGIN * 2)) return MARGIN
  return Math.min(Math.max(start, MARGIN), extent - MARGIN - size)
}

// The anchor nearest where an area was dropped (by its centre, in thirds of
// the page), and its offset from that anchor measured inward: the inverse of
// anchored().
export function anchorFor(rect, pageWidth, pageHeight) {
  const cx = rect.left + (rect.width / 2)
  const cy = rect.bottom + (rect.height / 2)
  const horizontal = cx < pageWidth / 3 ? "left" : cx > (pageWidth * 2) / 3 ? "right" : "center"
  const vertical = cy < pageHeight / 3 ? "bottom" : cy > (pageHeight * 2) / 3 ? "top" : "middle"
  const anchor = horizontal === "center" && vertical === "middle" ? "center" : `${vertical}_${horizontal}`
  const x = horizontal === "left" ? rect.left : horizontal === "right" ? pageWidth - rect.left - rect.width
    : rect.left + (rect.width / 2) - (pageWidth / 2)
  const y = vertical === "bottom" ? rect.bottom : vertical === "top" ? pageHeight - rect.bottom - rect.height
    : rect.bottom + (rect.height / 2) - (pageHeight / 2)
  return { anchor, x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 }
}
