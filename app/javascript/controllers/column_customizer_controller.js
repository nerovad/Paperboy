import { Controller } from "@hotwired/stimulus";
import Sortable from "sortablejs";

// Drives the "Customize columns & filters" modal on the Inbox and Submissions
// tables. Lets a user reorder, show/hide, and add form-field columns, capped at
// however many columns fit the table container. Saves the layout per-user and
// reloads so the server re-renders columns + filters.
//
// Records grids opt out of the cap with `scrollable: true`: they scroll
// horizontally (see .records-table-wrapper), so a table is allowed to be wider
// than its container and every column of the record stays reachable.
export default class extends Controller {
  static targets = [
    "backdrop", "shownList", "availableList",
    "formSelect", "fieldSelect", "addButton", "capacity", "saveButton",
    "tableContainer",
  ];
  static values = {
    page: String,
    saveUrl: String,
    catalog: Object,
    minColPx: { type: Number, default: 150 },
    scrollable: { type: Boolean, default: false },
  };

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape") this.close(); };
    document.addEventListener("keydown", this._escHandler);
    this.populateFormSelect();
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler);
    this.shownSortable?.destroy();
    this.availableSortable?.destroy();
  }

  open() {
    this.backdropTarget.style.display = "flex";
    this.initSortables();
    this.updateCapacity();
  }

  close() {
    this.backdropTarget.style.display = "none";
  }

  backdropClick(event) {
    if (event.target === this.backdropTarget) this.close();
  }

  // ----- Sortable wiring -------------------------------------------------

  initSortables() {
    if (this.shownSortable) return; // once
    const onChange = () => this.updateCapacity();

    this.shownSortable = Sortable.create(this.shownListTarget, {
      group: "columns",
      animation: 150,
      filter: ".is-locked",
      onMove: (evt) => !evt.related.classList.contains("is-locked"),
      onAdd: (evt) => {
        // Reject a drag into "Shown" that would overflow the container.
        if (this.shownCount() > this.maxCols()) {
          this.availableListTarget.appendChild(evt.item);
        }
        onChange();
      },
      onSort: onChange,
    });

    this.availableSortable = Sortable.create(this.availableListTarget, {
      group: "columns",
      animation: 150,
      onAdd: onChange,
      onSort: onChange,
    });
  }

  // ----- Capacity / fit --------------------------------------------------

  maxCols() {
    // A horizontally scrolling grid has no width limit to fit within.
    if (this.scrollableValue) return Infinity;

    const width = this.hasTableContainerTarget
      ? this.tableContainerTarget.clientWidth
      : this.element.clientWidth;
    // Reserve room for the trailing action/customize column.
    return Math.max(1, Math.floor(width / this.minColPxValue) - 1);
  }

  shownCount() {
    return this.shownListTarget.querySelectorAll(".cc-chip").length;
  }

  atCapacity() {
    return this.shownCount() >= this.maxCols();
  }

  updateCapacity() {
    const full = this.atCapacity();
    const count = this.shownCount();
    const max = this.maxCols();
    if (this.hasCapacityTarget) {
      if (this.scrollableValue) {
        this.capacityTarget.textContent = `${count} column${count === 1 ? "" : "s"} — the table scrolls sideways`;
      } else {
        this.capacityTarget.textContent = full
          ? `${count} of ${max} columns — no room for more`
          : `${count} of ${max} columns`;
      }
      this.capacityTarget.classList.toggle("is-full", full);
    }
    this.setAddDisabled(full);
  }

  setAddDisabled(disabled) {
    [this.addButtonTarget, this.formSelectTarget, this.fieldSelectTarget].forEach((el) => {
      if (el) el.disabled = disabled;
    });
  }

  // ----- Add a field from a form ----------------------------------------

  populateFormSelect() {
    if (!this.hasFormSelectTarget) return;
    const catalog = this.catalogValue || {};
    Object.keys(catalog).forEach((formName) => {
      const opt = document.createElement("option");
      opt.value = formName;
      opt.textContent = formName;
      this.formSelectTarget.appendChild(opt);
    });
  }

  formChanged() {
    const catalog = this.catalogValue || {};
    const entry = catalog[this.formSelectTarget.value];
    this.fieldSelectTarget.innerHTML = '<option value="">Select a field…</option>';
    if (!entry) return;
    entry.fields.forEach((f) => {
      const opt = document.createElement("option");
      opt.value = f.name;
      opt.textContent = f.label;
      opt.dataset.label = f.label;
      this.fieldSelectTarget.appendChild(opt);
    });
  }

  addField() {
    if (this.atCapacity()) return;
    const formName = this.formSelectTarget.value;
    const catalog = this.catalogValue || {};
    const entry = catalog[formName];
    const fieldName = this.fieldSelectTarget.value;
    if (!entry || !fieldName) return;

    const klass = entry.class_name;
    const id = `field::${klass}::${fieldName}`;
    // Skip if already shown.
    if (this.shownListTarget.querySelector(`[data-id="${CSS.escape(id)}"]`)) return;

    const selected = this.fieldSelectTarget.selectedOptions[0];
    const label = `${selected.dataset.label} (${formName})`;

    const li = document.createElement("li");
    li.className = "cc-chip";
    li.dataset.id = id;
    li.dataset.custom = "true";
    li.dataset.form = klass;
    li.dataset.field = fieldName;
    li.dataset.label = label;
    li.innerHTML = `<span class="cc-chip__label"></span>` +
      `<button type="button" class="cc-chip__remove" data-action="column-customizer#remove" aria-label="Hide column">✕</button>`;
    li.querySelector(".cc-chip__label").textContent = label;
    this.shownListTarget.appendChild(li);
    this.updateCapacity();
  }

  // Remove (hide) a shown column — moves it back to Available for builtins,
  // or drops it entirely for custom fields.
  remove(event) {
    const chip = event.currentTarget.closest(".cc-chip");
    if (!chip || chip.dataset.locked === "true") return;
    if (chip.dataset.custom === "true") {
      chip.remove();
    } else {
      chip.querySelector(".cc-chip__remove")?.remove();
      this.availableListTarget.appendChild(chip);
    }
    this.updateCapacity();
  }

  // ----- Save ------------------------------------------------------------

  serialize() {
    return Array.from(this.shownListTarget.querySelectorAll(".cc-chip")).map((chip) => {
      if (chip.dataset.custom === "true") {
        return {
          type: "field",
          form: chip.dataset.form,
          field: chip.dataset.field,
          label: chip.dataset.label,
        };
      }
      return chip.dataset.id;
    });
  }

  async save() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content;
    this.saveButtonTarget.disabled = true;
    try {
      const res = await fetch(this.saveUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json",
        },
        body: JSON.stringify({ page: this.pageValue, fields: this.serialize() }),
      });
      if (res.ok) {
        window.location.reload();
      } else {
        this.saveButtonTarget.disabled = false;
        alert("Could not save your columns. Please try again.");
      }
    } catch (e) {
      this.saveButtonTarget.disabled = false;
      alert("Could not save your columns. Please try again.");
    }
  }
}
