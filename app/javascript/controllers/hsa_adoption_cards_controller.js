import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

// HSA Adoption Card Search: the Search and Browse screens.
//
// One controller serves both pages; `mode` says which. The search half works
// out what the single box contains (a surname, a case number, a date…),
// posts the parameters as JSON and renders the cards grouped by case. The
// browse half pages through the index one sorted page at a time. Both share
// the scanned-card viewer, which streams the PDF read-only from the server.
//
// Ported from the standalone AdoptionCardSearch.html page; the routing,
// tokenising and rendering are unchanged so a search behaves exactly as it
// did there.

const CARD_LABEL = {
  "": "any card",
  "CHILD": "the Child card",
  "BIRTH PARENTS": "the Birth Parents card",
  "ADOPTIVE PARENTS": "the Adoptive Parents card"
}
const DEFAULT_HINT = "Type anything — a surname, a partial case number, a date. Separate several " +
  "things with commas to require all of them; wrap anything containing a comma in quotes."
const TYPE_ORDER = { "CHILD": 1, "BIRTH PARENTS": 2, "ADOPTIVE PARENTS": 3 }
const CRITERIA = ["lastName", "firstName", "names", "anywhere", "caseNumber", "venOrA",
                  "dob", "dobYear", "closeDate", "finalDate", "anyDate", "anyText"]

const esc = s => String(s ?? "").replace(/[&<>"']/g, c =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]))
const nameOf = (f, l) => [f, l].filter(Boolean).join(" ").trim()
// The server already turns SQL Server's blank-date placeholder into null;
// this just guards against anything else arriving as a longer timestamp.
const fmtDate = d => (d ? String(d).slice(0, 10) : "")

// The browse table's columns: [sort key, heading, cell value, monospace?]
const BROWSE_COLS = [
  ["ID", "#", r => r.ID, true],
  ["CardType", "Card", r => r.CardType],
  ["Child_BirthLast", "Birth name", r => nameOf(r.Child_BirthFirst, r.Child_BirthLast)],
  ["Child_AdoptLast", "Adopted name", r => nameOf(r.Child_AdoptFirst, r.Child_AdoptLast)],
  ["Child_DOB", "DOB", r => fmtDate(r.Child_DOB)],
  ["BirthParent_1_Last", "Birth parent(s)",
    r => [nameOf(r.BirthParent_1_First, r.BirthParent_1_Last), nameOf(r.BirthParent_2_First, r.BirthParent_2_Last)].filter(Boolean).join(" · ")],
  ["AdoptParent_1_Last", "Adoptive parent(s)",
    r => [nameOf(r.AdoptParent_1_First, r.AdoptParent_1_Last), nameOf(r.AdoptParent_2_First, r.AdoptParent_2_Last)].filter(Boolean).join(" · ")],
  ["Case_Number", "Case #", r => r.Case_Number, true],
  ["VEN_Number", "VEN", r => r.VEN_Number, true],
  ["A_Number", "A #", r => r.A_Number, true],
  ["FinalDate_FinalDecree", "Final decree", r => fmtDate(r.FinalDate_FinalDecree)],
  ["CloseDate", "Closed", r => fmtDate(r.CloseDate)],
  ["GroupID", "Case group", r => (r.GroupID ? `${r.GroupID} · ${r.GroupStatus}` : "—")]
]

/* ---------- routing: work out what a piece of text is ---------- */
function route(text) {
  const t = text.trim()
  if (!t) return null
  const md = t.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$/)
  if (md) return { kind: "date", dob: `${md[3]}-${md[1].padStart(2, "0")}-${md[2].padStart(2, "0")}` }
  const iso = t.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
  if (iso) return { kind: "date", dob: `${iso[1]}-${iso[2].padStart(2, "0")}-${iso[3].padStart(2, "0")}` }
  if (/^(18|19|20)\d{2}$/.test(t)) return { kind: "year", dobYear: +t }
  const digits = t.replace(/\D/g, "")
  if (digits.length >= 4 && !/[a-z]/i.test(t)) {
    return digits.length <= 6 && !/[,\-]/.test(t)
      ? { kind: "venOrA", venOrA: t }
      : { kind: "case", caseNumber: t }
  }
  return { kind: "name", lastName: t }
}

/* Split the box on commas. Quotes protect a piece ("56-93-117, 599-4").
   Neighbouring unquoted numeric pieces are rejoined, so an unquoted case
   number typed beside a name still comes through whole. */
function tokenize(text) {
  const out = []
  let cur = "", q = false, wasQuoted = false
  const push = () => { const t = cur.trim(); if (t) out.push({ text: t, quoted: wasQuoted }); cur = ""; wasQuoted = false }
  for (const ch of text) {
    if (ch === '"') { q = !q; wasQuoted = true; continue }
    if (ch === "," && !q) { push(); continue }
    cur += ch
  }
  push()
  const kindOf = t => (route(t) || {}).kind
  const merged = []
  for (const piece of out) {
    const prev = merged[merged.length - 1]
    const k = kindOf(piece.text)
    if (prev && !prev.quoted && !piece.quoted && kindOf(prev.text) === "case" && (k === "case" || k === "venOrA"))
      prev.text += ", " + piece.text
    else merged.push({ ...piece })
  }
  return merged
}

export default class extends Controller {
  static targets = [
    // search
    "form", "box", "cardType", "go", "hint", "everywhere", "field", "fuzzy", "dobFuzzy", "meta", "results",
    // both
    "who",
    // browse
    "browseCardType", "browseStatus", "browsePageSize", "prev", "next", "where", "table",
    // viewer
    "viewer", "viewerLabel", "viewerPath", "viewerFrame", "viewerFail"
  ]
  static values = {
    mode: String,
    searchUrl: String,
    browseUrl: String,
    pdfUrl: String,
    shareConnected: Boolean,
    shareMessage: String
  }

  connect() {
    this.browse = { sortBy: "ID", sortDir: "ASC", page: 1, total: 0, rows: [], openId: null }
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    if (this.modeValue === "browse") this.loadBrowse()
    if (this.hasBoxTarget) this.boxTarget.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  keydown(event) {
    if (event.key === "Escape" && this.hasViewerTarget && !this.viewerTarget.hidden) this.closeViewer()
  }

  /* ================================ search ================================ */

  // Turn the box into parameters plus a plain-English plan for the hint.
  parseBox(text, everywhere) {
    const whole = text.trim()
    const p = {}, plan = []
    if (!whole) return { p, plan }

    const w = route(whole)
    const keepWhole = w && !whole.includes('"') &&
      (w.kind === "date" || w.kind === "year" || (w.kind === "case" && whole.includes("-")))
    const pieces = keepWhole ? [{ text: whole, quoted: false }] : tokenize(whole)

    if (everywhere) {
      p.anywhere = pieces.map(x => x.text).join("|")
      plan.push(pieces.map(x => `“${x.text}”`).join(" and ") + " anywhere on the card")
      return { p, plan }
    }

    const names = [], found = [], cases = [], vens = []
    for (const { text } of pieces) {
      const r = route(text); if (!r) continue
      if (r.kind === "name") names.push(text)
      else if (r.kind === "date") { p.anyDate = r.dob; plan.push(`any date = ${r.dob}`) }
      else if (r.kind === "year") { found.push(text); plan.push(`year ${text} on any date`) }
      else if (r.kind === "case") cases.push(text)
      else if (r.kind === "venOrA") vens.push(text)
    }
    if (cases.length === 1) { p.caseNumber = cases[0]; plan.push(`case number ${cases[0]}`) }
    else for (const c of cases) { found.push(c); plan.push(`number ${c} anywhere`) }
    if (vens.length === 1) { p.venOrA = vens[0]; plan.push(`VEN/A# ${vens[0]}`) }
    else for (const v of vens) { found.push(v); plan.push(`number ${v} anywhere`) }
    if (names.length === 1) {
      p.lastName = names[0]
      plan.unshift(`surname ${names[0]}` + (this.fuzzyTarget.checked ? " (and sound-alikes)" : ""))
    } else if (names.length > 1) {
      p.names = names.join("|")
      plan.unshift(`${names.join(" and ")} among the names`)
    }
    if (found.length) p.anywhere = found.join("|")
    return { p, plan }
  }

  updateHint() {
    const { plan } = this.parseBox(this.boxTarget.value, this.everywhereTarget.checked)
    const where = this.cardTypeTarget.value ? ` — must be on ${CARD_LABEL[this.cardTypeTarget.value]}` : ""
    this.hintTarget.textContent = plan.length ? "Looking for: " + plan.join("; ") + where + "." : DEFAULT_HINT
  }

  // Start from whatever the box parsed to, then layer the specific fields
  // on top. A field only ever narrows or overrides its own parameter.
  buildParams() {
    const { p } = this.parseBox(this.boxTarget.value, this.everywhereTarget.checked)
    for (const field of this.fieldTargets) {
      const v = field.value.trim()
      if (v !== "") p[field.dataset.key] = v
    }
    for (const k of Object.keys(p)) if (p[k] === "" || p[k] == null) delete p[k]
    if (p.dobYear) p.dobYear = +p.dobYear
    if (this.cardTypeTarget.value) p.cardType = this.cardTypeTarget.value
    p.fuzzy = this.fuzzyTarget.checked ? 1 : 0
    p.dobFuzzy = this.dobFuzzyTarget.checked ? 1 : 0
    return p
  }

  async search(event) {
    event.preventDefault()
    const p = this.buildParams()
    if (!CRITERIA.some(k => p[k] !== undefined)) { this.boxTarget.focus(); return }

    this.goTarget.disabled = true
    this.metaTarget.hidden = false
    this.metaTarget.textContent = "Searching…"
    this.resultsTarget.innerHTML = ""
    const started = performance.now()
    try {
      const rows = await this.post(this.searchUrlValue, p)
      const ms = Math.round(performance.now() - started)
      const cases = new Set(rows.map(r => r.GroupID ?? 0)).size
      this.metaTarget.innerHTML = `<strong>${rows.length}</strong> card${rows.length === 1 ? "" : "s"}
        across <strong>${cases}</strong> case${cases === 1 ? "" : "s"}
        <span>&middot; ${ms} ms</span>`
      this.renderResults(rows)
    } catch (err) {
      this.metaTarget.hidden = true
      this.resultsTarget.innerHTML = this.errorBlock("Search failed.", err)
    } finally {
      this.goTarget.disabled = false
    }
  }

  clear() {
    this.formTarget.reset()
    this.fuzzyTarget.checked = true
    this.metaTarget.hidden = true
    this.resultsTarget.innerHTML = ""
    this.boxTarget.focus()
    this.updateHint()
  }

  renderResults(rows) {
    if (!rows.length) {
      this.resultsTarget.innerHTML = `<div class="hsa-ac-empty">No cards matched.<br>
        <span class="hsa-ac-note">Try a shorter fragment, or tick &ldquo;allow one wrong part in the date of
        birth&rdquo; if you are searching a date.</span></div>`
      return
    }
    const groups = new Map()
    for (const r of rows) {
      const k = r.GroupID ?? 0
      if (!groups.has(k)) groups.set(k, [])
      groups.get(k).push(r)
    }
    let html = ""
    for (const [gid, cards] of groups) {
      cards.sort((a, b) => (TYPE_ORDER[a.CardType] || 9) - (TYPE_ORDER[b.CardType] || 9))
      const st = cards[0].GroupStatus || "UNLINKED"
      const amb = cards.some(c => c.Ambiguous)
      const conflict = cards.map(c => c.Conflicts).find(Boolean)
      html += `<section class="hsa-ac-case">
        <h2><span class="hsa-ac-badge is-${esc(st)}">${esc(st)}</span>
          ${gid ? `<span class="hsa-ac-grp">Case group ${esc(gid)}</span>` : '<span class="hsa-ac-grp">Not linked to a case</span>'}
          ${amb ? '<span class="hsa-ac-badge is-REVIEW">ambiguous</span>' : ""}
          <span class="hsa-ac-grp">${cards.length} card${cards.length > 1 ? "s" : ""}</span></h2>
        ${conflict ? `<div class="hsa-ac-conflict">${esc(conflict)}</div>` : ""}
        <div class="hsa-ac-cards">${cards.map(c => this.renderCard(c)).join("")}</div>
      </section>`
    }
    this.resultsTarget.innerHTML = html
  }

  renderCard(c) {
    const row = (dt, dd, mono) => (dd ? `<dt>${esc(dt)}</dt><dd${mono ? ' class="hsa-ac-mono"' : ""}>${esc(dd)}</dd>` : "")
    let body = ""
    if (c.CardType === "CHILD" || c.CardType === "BIRTH PARENTS") body += row("Birth name", nameOf(c.Child_BirthFirst, c.Child_BirthLast))
    if (c.CardType === "CHILD" || c.CardType === "ADOPTIVE PARENTS") body += row("Adopted name", nameOf(c.Child_AdoptFirst, c.Child_AdoptLast))
    body += row("Date of birth", fmtDate(c.Child_DOB))
    const bp = [nameOf(c.BirthParent_1_First, c.BirthParent_1_Last), nameOf(c.BirthParent_2_First, c.BirthParent_2_Last)].filter(Boolean)
    const ap = [nameOf(c.AdoptParent_1_First, c.AdoptParent_1_Last), nameOf(c.AdoptParent_2_First, c.AdoptParent_2_Last)].filter(Boolean)
    if (bp.length) body += row(bp.length > 1 ? "Birth parents" : "Birth parent", bp.join("  ·  "))
    if (ap.length) body += row(ap.length > 1 ? "Adoptive parents" : "Adoptive parent", ap.join("  ·  "))
    body += row("Case number", c.Case_Number, true)
    body += row("VEN", c.VEN_Number, true)
    body += row("A number", c.A_Number, true)
    body += row("Final decree", fmtDate(c.FinalDate_FinalDecree))
    body += row("Closed", fmtDate(c.CloseDate))
    body += row("Notes", c.Notes)

    const direct = c.HitType === "DIRECT"
    return `<div class="hsa-ac-card">
      <h3>${esc(c.CardType)}
        ${direct ? '<span class="hsa-ac-badge is-DIRECT">match</span>' : ""}
        <span class="hsa-ac-grp hsa-ac-mono">#${esc(c.ID)}</span></h3>
      ${direct && c.MatchedOn ? `<div class="hsa-ac-matched">Matched on: ${esc(c.MatchedOn)}</div>` : ""}
      <dl class="hsa-ac-fields">${body}</dl>
      ${c.Filepath ? `<div class="hsa-ac-pdf">
          <button type="button" class="btn pdf compact" data-view="${esc(c.Filepath)}"
                  data-label="${esc(c.CardType)} · card #${esc(c.ID)}">View scanned card</button>
        </div>` : ""}
    </div>`
  }

  resultsClick(event) {
    const view = event.target.closest("button[data-view]")
    if (view) this.openViewer(view.dataset.view, view.dataset.label)
  }

  /* ================================ browse ================================ */

  browseParams() {
    const p = { sortBy: this.browse.sortBy, sortDir: this.browse.sortDir, page: this.browse.page,
                pageSize: +this.browsePageSizeTarget.value }
    if (this.browseCardTypeTarget.value) p.cardType = this.browseCardTypeTarget.value
    if (this.browseStatusTarget.value) p.status = this.browseStatusTarget.value
    return p
  }

  async loadBrowse() {
    this.browse.openId = null
    this.tableTarget.innerHTML = `<div class="hsa-ac-empty">Loading…</div>`
    this.prevTarget.disabled = this.nextTarget.disabled = true
    try {
      const rows = await this.post(this.browseUrlValue, this.browseParams())
      this.browse.rows = rows
      this.browse.total = rows.length ? (rows[0].TotalRows ?? rows.length) : 0
      this.renderBrowse()
    } catch (err) {
      this.tableTarget.innerHTML = this.errorBlock("Could not load cards.", err)
      this.whereTarget.textContent = ""
    }
  }

  renderBrowse() {
    const b = this.browse
    const size = +this.browsePageSizeTarget.value
    const pages = Math.max(1, Math.ceil(b.total / size))
    if (b.page > pages) b.page = pages
    const from = b.total ? (b.page - 1) * size + 1 : 0
    const to = Math.min(b.total, b.page * size)
    this.whereTarget.textContent = b.total
      ? `${from.toLocaleString()}–${to.toLocaleString()} of ${b.total.toLocaleString()} · page ${b.page} of ${pages}`
      : "no cards"
    this.prevTarget.disabled = b.page <= 1
    this.nextTarget.disabled = b.page >= pages

    if (!b.rows.length) { this.tableTarget.innerHTML = `<div class="hsa-ac-empty">No cards to show.</div>`; return }
    const th = BROWSE_COLS.map(([key, label]) => {
      const on = key === b.sortBy
      return `<th data-sort="${key}" class="${on ? "is-sorted" : ""}">${esc(label)}${on ? `<span class="hsa-ac-dir">${b.sortDir === "ASC" ? "▲" : "▼"}</span>` : ""}</th>`
    }).join("")
    const tr = b.rows.map(r => `<tr class="hsa-ac-row" data-id="${esc(r.ID)}">` +
      BROWSE_COLS.map(([, , get, mono]) => `<td${mono ? ' class="hsa-ac-mono"' : ""}>${esc(get(r) ?? "")}</td>`).join("") +
      `<td class="hsa-ac-notes" title="${esc(r.Notes ?? "")}">${esc(r.Notes ?? "")}</td></tr>`).join("")
    this.tableTarget.innerHTML = `<table class="hsa-ac-browse"><thead><tr>${th}<th>Notes</th></tr></thead><tbody>${tr}</tbody></table>`
  }

  tableClick(event) {
    const th = event.target.closest("th[data-sort]")
    if (th) {
      if (this.browse.sortBy === th.dataset.sort) this.browse.sortDir = this.browse.sortDir === "ASC" ? "DESC" : "ASC"
      else { this.browse.sortBy = th.dataset.sort; this.browse.sortDir = "ASC" }
      this.browse.page = 1
      this.loadBrowse()
      return
    }
    const view = event.target.closest("button[data-view]")
    if (view) { this.openViewer(view.dataset.view, view.dataset.label); return }

    const tr = event.target.closest("tr.hsa-ac-row")
    if (!tr) return
    // toggle a detail row under the clicked one, showing the whole card
    const id = tr.dataset.id
    const existing = tr.nextElementSibling
    this.tableTarget.querySelectorAll("tr.hsa-ac-detail").forEach(x => x.remove())
    this.tableTarget.querySelectorAll("tr.hsa-ac-row.is-open").forEach(x => x.classList.remove("is-open"))
    if (existing && existing.classList.contains("hsa-ac-detail") && this.browse.openId === id) { this.browse.openId = null; return }
    const r = this.browse.rows.find(x => String(x.ID) === id); if (!r) return
    this.browse.openId = id
    tr.classList.add("is-open")
    const d = document.createElement("tr")
    d.className = "hsa-ac-detail"
    d.innerHTML = `<td colspan="${BROWSE_COLS.length + 1}">${this.renderCard({ ...r, HitType: null })}</td>`
    tr.after(d)
  }

  browseFilterChanged() { this.browse.page = 1; this.loadBrowse() }
  prevPage() { if (this.browse.page > 1) { this.browse.page--; this.loadBrowse() } }
  nextPage() { this.browse.page++; this.loadBrowse() }

  /* ================================ viewer ================================ */

  openViewer(path, label) {
    this.viewerLabelTarget.textContent = label || "Scanned card"
    this.viewerPathTarget.textContent = path
    this.viewerTarget.hidden = false
    if (!this.shareConnectedValue) {
      this.viewerFrameTarget.hidden = true
      this.viewerFailTarget.hidden = false
      this.viewerFailTarget.innerHTML = `<div><strong>The scanned card cannot be shown yet.</strong>
        <p>${esc(this.shareMessageValue || "The scanned-cards share is not reachable.")}</p></div>`
      return
    }
    this.viewerFailTarget.hidden = true
    this.viewerFrameTarget.hidden = false
    this.viewerFrameTarget.src = `${this.pdfUrlValue}?path=${encodeURIComponent(path)}`
  }

  closeViewer() {
    this.viewerTarget.hidden = true
    this.viewerFrameTarget.src = "about:blank"   // stop rendering / release the file handle
  }

  viewerBackdrop(event) {
    if (event.target === this.viewerTarget) this.closeViewer()
  }

  /* ================================ shared ================================ */

  async post(url, p) {
    const r = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify(p)
    })
    const text = await r.text()
    if (!r.ok) throw new Error(text || ("HTTP " + r.status))
    let data
    try { data = JSON.parse(text) } catch { throw new Error("The server did not return a result. You may need to sign in again.") }
    if (data.error) {
      const e = new Error(data.error)
      e.detail = data.detail && data.detail !== data.error ? data.detail : null
      throw e
    }
    if (data.user && this.hasWhoTarget) {
      this.whoTarget.textContent = `${this.modeValue === "browse" ? "Browsing" : "Searching"} as ${data.user}`
    }
    return data.rows || []
  }

  errorBlock(title, err) {
    return `<div class="hsa-ac-error"><strong>${esc(title)}</strong><br>${esc(err.message)}
      ${err.detail ? `<div class="hsa-ac-note hsa-ac-mono">${esc(err.detail)}</div>` : ""}</div>`
  }

  // Kept for parity with the rest of the app: anything that must interrupt
  // goes through the shared modal, never window.alert.
  async notify(title, message) {
    await pbAlert({ title, message })
  }
}
