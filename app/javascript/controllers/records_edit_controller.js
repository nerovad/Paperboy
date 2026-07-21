import { Controller } from "@hotwired/stimulus";

// Inline editing for the Records grid with an explicit save step. The grid opens
// read-only; "Edit" puts it into edit mode. Editing a cell then STAGES the change
// locally (marked dirty) — nothing is written until the user clicks "Review &
// Save", which opens a modal summarizing every change. Only on confirming the
// modal are all changes sent in one batch (PATCH) and finalized.
//
// Edit mode is a convenience, not a permission: cells are only rendered editable
// when the viewer holds the table's record_edit grant, and the PATCH endpoint
// re-checks that grant regardless of what the page offers.
export default class extends Controller {
  static values = { url: String };
  static targets = ["savebar", "count", "modal", "modalList", "confirmCount", "modeButton"];

  connect() {
    this.pending = new Map(); // "id::column" -> { id, column, label, oldText, value, rowLabel }
    this.editing = false;
  }

  key(id, column) {
    return `${id}::${column}`;
  }

  // ---- edit mode -----------------------------------------------------------
  // Staged changes survive leaving edit mode; the savebar stays up so they can
  // still be reviewed, saved or discarded.
  toggleMode() {
    this.editing = !this.editing;
    this.element.classList.toggle("is-edit-mode", this.editing);
    if (this.hasModeButtonTarget) {
      this.modeButtonTarget.textContent = this.editing ? "Done editing" : "Edit";
      this.modeButtonTarget.classList.toggle("approve", this.editing);
    }
  }

  // ---- open an inline input ------------------------------------------------
  start(event) {
    if (!this.editing) return;

    const cell = event.currentTarget;
    if (cell.classList.contains("is-editing")) return;
    cell.classList.add("is-editing");
    if (cell.dataset.origHtml === undefined) {
      cell.dataset.origHtml = cell.innerHTML;
      cell.dataset.origRaw = cell.dataset.raw || "";
    }

    const kind = cell.dataset.kind;
    const input = document.createElement("input");
    input.type = kind === "date" ? "date" : kind === "currency" ? "number" : "text";
    if (kind === "currency") input.step = "0.01";
    input.className = "records-edit-input";
    input.value = cell.dataset.raw || "";

    cell.innerHTML = "";
    cell.appendChild(input);
    input.focus();
    input.select();

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") { e.preventDefault(); this.stage(cell, input.value); }
      else if (e.key === "Escape") { e.preventDefault(); this.restore(cell); }
    });
    input.addEventListener("blur", () => {
      if (cell.classList.contains("is-editing")) this.stage(cell, input.value);
    });
  }

  // ---- stage / revert a single cell ---------------------------------------
  stage(cell, value) {
    cell.classList.remove("is-editing");
    const k = this.key(cell.dataset.id, cell.dataset.column);

    if (value === cell.dataset.origRaw) {
      this.pending.delete(k);
      this.clearCellState(cell);
    } else {
      this.pending.set(k, {
        id: cell.dataset.id,
        column: cell.dataset.column,
        label: cell.dataset.label,
        oldText: this.stripHtml(cell.dataset.origHtml),
        value,
        rowLabel: this.rowLabel(cell),
      });
      cell.dataset.raw = value;
      cell.innerHTML = `<span class="records-cell__value">${this.escape(value)}</span>`;
      cell.classList.add("is-dirty");
    }
    this.refreshBar();
  }

  restore(cell) {
    cell.classList.remove("is-editing");
    const k = this.key(cell.dataset.id, cell.dataset.column);
    const staged = this.pending.get(k);
    cell.innerHTML = staged
      ? `<span class="records-cell__value">${this.escape(staged.value)}</span>`
      : (cell.dataset.origHtml ?? cell.innerHTML);
  }

  clearCellState(cell) {
    if (cell.dataset.origHtml !== undefined) cell.innerHTML = cell.dataset.origHtml;
    cell.classList.remove("is-dirty");
    cell.dataset.raw = cell.dataset.origRaw ?? cell.dataset.raw;
    delete cell.dataset.origHtml;
    delete cell.dataset.origRaw;
  }

  refreshBar() {
    const n = this.pending.size;
    if (this.hasSavebarTarget) this.savebarTarget.hidden = n === 0;
    if (this.hasCountTarget) this.countTarget.textContent = n;
  }

  // ---- review modal --------------------------------------------------------
  openModal() {
    if (this.pending.size === 0) return;
    this.modalListTarget.innerHTML = [...this.pending.values()].map((c) =>
      `<li class="rsm-item">
         <span class="rsm-row">${this.escape(c.rowLabel)}</span>
         <span class="rsm-col">${this.escape(c.label)}</span>
         <span class="rsm-change"><span class="rsm-old">${this.escape(c.oldText || "—")}</span> → <span class="rsm-new">${this.escape(c.value || "—")}</span></span>
       </li>`
    ).join("");
    if (this.hasConfirmCountTarget) this.confirmCountTarget.textContent = `(${this.pending.size})`;
    this.modalTarget.hidden = false;
  }

  closeModal() {
    this.modalTarget.hidden = true;
  }

  backdropClick(event) {
    if (event.target === this.modalTarget) this.closeModal();
  }

  discardAll() {
    for (const { id, column } of this.pending.values()) {
      const cell = this.cell(id, column);
      if (cell) this.clearCellState(cell);
    }
    this.pending.clear();
    this.refreshBar();
    this.closeModal();
  }

  // ---- commit all staged changes ------------------------------------------
  async save() {
    if (this.pending.size === 0) return;
    const changes = [...this.pending.values()].map((c) => ({ id: c.id, column: c.column, value: c.value }));
    const token = document.querySelector('meta[name="csrf-token"]')?.content;

    try {
      const res = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json",
        },
        body: JSON.stringify({ changes }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.ok) {
        for (const [k, html] of Object.entries(data.cells || {})) {
          const [id, column] = k.split("::");
          const cell = this.cell(id, column);
          if (cell) {
            cell.innerHTML = html;
            cell.classList.remove("is-dirty");
            delete cell.dataset.origHtml;
            delete cell.dataset.origRaw;
          }
        }
        this.pending.clear();
        this.refreshBar();
        this.closeModal();
      } else {
        alert((data.errors || ["Could not save your changes."]).join("\n"));
      }
    } catch (e) {
      alert("Could not save your changes.");
    }
  }

  // ---- helpers -------------------------------------------------------------
  cell(id, column) {
    return this.element.querySelector(`td[data-id="${CSS.escape(id)}"][data-column="${CSS.escape(column)}"]`);
  }

  rowLabel(cell) {
    const first = cell.closest("tr")?.querySelector("td");
    return first ? first.innerText.trim() : `#${cell.dataset.id}`;
  }

  stripHtml(html) {
    const d = document.createElement("div");
    d.innerHTML = html || "";
    return d.innerText.trim();
  }

  escape(value) {
    const d = document.createElement("div");
    d.textContent = value == null ? "" : String(value);
    return d.innerHTML;
  }
}
