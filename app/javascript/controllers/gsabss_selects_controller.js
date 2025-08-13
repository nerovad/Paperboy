// app/javascript/controllers/gsabss_selects_controller.js
import { Controller } from "@hotwired/stimulus"

// Get a Turbo reference regardless of import style
function getTurbo() {
  // turbo-rails puts Turbo on window; some setups also allow import "@hotwired/turbo"
  return window.Turbo
}

export default class extends Controller {
  static targets = ["agency", "division", "department", "unit"]

  // ===== public handlers =====
  loadDivisions = async () => {
    this._prep(this.divisionTarget, [this.departmentTarget, this.unitTarget])
    await this._fetchRenderOrFallback(
      `/lookups/divisions?agency=${encodeURIComponent(this.agencyTarget.value)}`,
      "division-select"
    )
    this._enable(this.divisionTarget)
  }

  loadDepartments = async () => {
    this._prep(this.departmentTarget, [this.unitTarget])
    await this._fetchRenderOrFallback(
      `/lookups/departments?division=${encodeURIComponent(this.divisionTarget.value)}`,
      "department-select"
    )
    this._enable(this.departmentTarget)
  }

  loadUnits = async () => {
    this._prep(this.unitTarget, [])
    await this._fetchRenderOrFallback(
      `/lookups/units?department=${encodeURIComponent(this.departmentTarget.value)}`,
      "unit-select"
    )
    this._enable(this.unitTarget)
  }

  // ===== internals =====
  _prep(primary, downstream = []) {
    this._setOptions(primary, [["", "Loading…"]], true)
    downstream.forEach(sel => this._setOptions(sel, [["", "Select one"]], true))
    this._checkDuplicateIds()
  }

  _setOptions(select, pairs, disabled) {
    if (!select) return
    select.innerHTML = pairs.map(([v, t]) => `<option value="${v}">${t}</option>`).join("")
    select.disabled = !!disabled
    console.log("[GSABSS] setOptions:", { id: select.id, disabled: select.disabled, count: pairs.length })
  }

  _enable(select) {
    if (!select) return
    select.disabled = false
    console.log("[GSABSS] enabled:", select.id)
  }

  async _fetchRenderOrFallback(url, expectedId) {
    console.log("[GSABSS] fetching:", url)
    let text = ""
    try {
      const res = await fetch(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
      text = await res.text()
      console.log("[GSABSS] fetch result:", {
        status: res.status,
        ok: res.ok,
        contentType: res.headers.get("Content-Type"),
        preview: text.slice(0, 200).replace(/\n/g, "⏎")
      })
      if (!res.ok) return

      // Try normal Turbo application
      const Turbo = getTurbo()
      if (Turbo?.renderStreamMessage) {
        try {
          Turbo.renderStreamMessage(text)
          console.log("[GSABSS] Turbo.renderStreamMessage applied")
        } catch (e) {
          console.error("[GSABSS] Turbo.renderStreamMessage error:", e)
        }
      } else {
        console.warn("[GSABSS] Turbo not found on window. Proceeding to fallback parse.")
      }

      // Verify the select actually got options. If not, do a manual fallback.
      queueMicrotask(() => {
        const live = document.getElementById(expectedId)
        const count = live ? live.querySelectorAll("option").length : 0
        console.log(`[GSABSS] post-render check → #${expectedId} option count:`, count)
        if (!live || count <= 1) {
          console.warn(`[GSABSS] fallback kicking in for #${expectedId}`)
          this._applyStreamFallback(text, expectedId)
        }
      })
    } catch (e) {
      console.error("[GSABSS] fetch exception:", e)
      // Worst-case: keep “Select one”
    }
  }

  // Parse the <turbo-stream> text and copy the <select> options into the live select
  _applyStreamFallback(streamHtml, selectId) {
    try {
      const tmp = document.createElement("div")
      tmp.innerHTML = streamHtml
      // Look for <turbo-stream action="replace"><template>...<select id="selectId">...</select>
      const tpl = tmp.querySelector("turbo-stream[action='replace'] template")
      const replacementSelect = tpl?.content?.querySelector?.(`#${CSS.escape(selectId)}`)
      if (!replacementSelect) {
        console.error("[GSABSS] fallback: no replacement <select> found in stream for", selectId)
        return
      }
      const live = document.getElementById(selectId)
      if (!live) {
        console.error("[GSABSS] fallback: live select not found:", selectId)
        return
      }
      live.innerHTML = replacementSelect.innerHTML
      live.disabled = false
      console.log("[GSABSS] fallback applied →", selectId, "options:", live.querySelectorAll("option").length)
    } catch (e) {
      console.error("[GSABSS] fallback parse/apply failed:", e)
    }
  }

  _checkDuplicateIds() {
    ["agency-select", "division-select", "department-select", "unit-select"].forEach(id => {
      const nodes = document.querySelectorAll(`#${CSS.escape(id)}`)
      if (nodes.length > 1) {
        console.warn(`[GSABSS] DUPLICATE ID DETECTED: #${id} (count=${nodes.length})`, nodes)
      }
    })
  }
}
