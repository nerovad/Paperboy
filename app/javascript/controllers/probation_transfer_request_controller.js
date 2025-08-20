// app/javascript/controllers/probation_transfer_request_controller.js
import { Controller } from "@hotwired/stimulus";

// Uses window.Choices (exactly like your old controller)
export default class extends Controller {
  static targets = [
    // selects
    "adultSelect", "juvenileSelect", "adminSelect",
    // “Other” groups/inputs
    "adultOtherGroup", "adultOtherInput",
    "juvenileOtherGroup", "juvenileOtherInput",
    "adminOtherGroup", "adminOtherInput",
    // single hidden field bound to model column
    "combinedField"
  ];

  connect() {
    const ChoicesLib = window.Choices;
    if (!ChoicesLib) { console.error("Choices global not found"); return; }

    // ---- Init choices for each section the same way as before ----
    this.adult = this._initSelect(this.adultSelectTarget);
    this.juvenile = this._initSelect(this.juvenileSelectTarget);
    this.admin = this._initSelect(this.adminSelectTarget);

    // ---- Wire change handlers (show/hide Other, keep hidden field in sync) ----
    this._onAdultChange = () => this._syncAll();
    this._onJuvChange   = () => this._syncAll();
    this._onAdminChange = () => this._syncAll();

    this.adultSelectTarget.addEventListener("change", this._onAdultChange);
    this.juvenileSelectTarget.addEventListener("change", this._onJuvChange);
    this.adminSelectTarget.addEventListener("change", this._onAdminChange);

    // Other inputs affect final value too
    this._onAdultOther = () => this._syncAll();
    this._onJuvOther   = () => this._syncAll();
    this._onAdminOther = () => this._syncAll();

    this.adultOtherInputTarget.addEventListener("input", this._onAdultOther);
    this.juvenileOtherInputTarget.addEventListener("input", this._onJuvOther);
    this.adminOtherInputTarget.addEventListener("input", this._onAdminOther);

    // Rehydrate any existing DB value (comma-separated string)
    this._restoreFromCombined();

    // Final sync on submit (Turbo or not)
    this.element.closest("form")?.addEventListener("submit", () => this._syncAll());
  }

  disconnect() {
    // Remove change listeners
    this.adultSelectTarget?.removeEventListener("change", this._onAdultChange);
    this.juvenileSelectTarget?.removeEventListener("change", this._onJuvChange);
    this.adminSelectTarget?.removeEventListener("change", this._onAdminChange);

    this.adultOtherInputTarget?.removeEventListener("input", this._onAdultOther);
    this.juvenileOtherInputTarget?.removeEventListener("input", this._onJuvOther);
    this.adminOtherInputTarget?.removeEventListener("input", this._onAdminOther);

    // Tear down dropdown positioning listeners & Choices instances
    this._teardownSelect(this.adult);
    this._teardownSelect(this.juvenile);
    this._teardownSelect(this.admin);
  }

  // ===== Helpers =====

  _initSelect(selectEl) {
    const ChoicesLib = window.Choices;

    const choices = new ChoicesLib(selectEl, {
      removeItemButton: true,
      placeholderValue: "Select destination(s)…",
      searchPlaceholderValue: "Type to filter…",
      shouldSort: false,
      allowHTML: false
    });

    // Defer until Choices builds wrapper/dropdown
    const handle = { selectEl, choices };
    setTimeout(() => this._setupDropdownPositioning(handle), 0);
    return handle;
  }

  _setupDropdownPositioning(handle) {
    const { selectEl } = handle;

    handle.wrapper  = selectEl.closest(".choices");
    handle.dropdown = handle.wrapper?.querySelector(".choices__list--dropdown");

    if (!handle.wrapper || !handle.dropdown) return;

    // binders
    handle.onShow   = () => this._fixDropdown(handle);
    handle.onHide   = () => this._resetDropdown(handle);
    handle.onReflow = () => this._positionDropdown(handle);

    selectEl.addEventListener("showDropdown", handle.onShow);
    selectEl.addEventListener("hideDropdown", handle.onHide);
    window.addEventListener("scroll", handle.onReflow, true);
    window.addEventListener("resize", handle.onReflow);
  }

  _teardownSelect(handle) {
    if (!handle) return;
    const { selectEl, choices, onShow, onHide, onReflow } = handle;

    if (selectEl && onShow)  selectEl.removeEventListener("showDropdown", onShow);
    if (selectEl && onHide)  selectEl.removeEventListener("hideDropdown", onHide);
    if (onReflow) {
      window.removeEventListener("scroll", onReflow, true);
      window.removeEventListener("resize", onReflow);
    }
    if (choices?.destroy) choices.destroy();
    this._resetDropdown(handle);
  }

  _fixDropdown(handle) {
    const { dropdown } = handle;
    if (!dropdown) return;
    const setImp = (prop, val) => dropdown.style.setProperty(prop, val, "important");
    setImp("position", "fixed");
    setImp("z-index", "2147483647");
    setImp("right", "auto");
    this._positionDropdown(handle);
  }

  _positionDropdown(handle) {
    const { wrapper, dropdown } = handle;
    if (!wrapper || !dropdown) return;
    const r = wrapper.getBoundingClientRect();
    const setImp = (prop, val) => dropdown.style.setProperty(prop, val, "important");
    setImp("left", `${Math.round(r.left)}px`);
    setImp("top",  `${Math.round(r.bottom)}px`);
    setImp("width", `${Math.round(r.width)}px`);
    setImp("box-sizing", "border-box");
    setImp("max-height", "50vh");
    setImp("overflow", "auto");
  }

  _resetDropdown(handle) {
    handle?.dropdown?.removeAttribute("style");
  }

  // ---- Rehydrate from hidden column string ----
  _restoreFromCombined() {
    const raw = (this.combinedFieldTarget?.value || "").trim();
    if (!raw) { this._syncAll(); return; }

    const items = raw.split(",").map(s => s.trim()).filter(Boolean);
    // naive partitioning: try to set known options back to their menus;
    // “Other (Xxx): …” is handled in _syncAll via show/hide + input value
    const all = [
      { handle: this.adult,    options: this._optionsOf(this.adultSelectTarget) },
      { handle: this.juvenile, options: this._optionsOf(this.juvenileSelectTarget) },
      { handle: this.admin,    options: this._optionsOf(this.adminSelectTarget) }
    ];

    const others = [];

    items.forEach(v => {
      const isOther = /^other\s*(\(|:)/i.test(v);
      if (isOther) { others.push(v); return; }
      const slot = all.find(s => s.options.has(v));
      if (slot) slot.handle.choices.setChoiceByValue(v);
    });

    // Push “Other (Bureau): text” back into the respective input if possible
    others.forEach(v => {
      // Match formats like "Other (Adult): foo bar"
      const m = /^Other\s*\((Adult|Juvenile|Administrative)\)\s*:\s*(.+)$/i.exec(v);
      if (!m) return;
      const bureau = m[1].toLowerCase();
      const text   = m[2];

      if (bureau === "adult") {
        this._ensureOtherVisible(this.adult, this.adultOtherGroupTarget);
        this.adultOtherInputTarget.value = text;
      } else if (bureau === "juvenile") {
        this._ensureOtherVisible(this.juvenile, this.juvenileOtherGroupTarget);
        this.juvenileOtherInputTarget.value = text;
      } else {
        this._ensureOtherVisible(this.admin, this.adminOtherGroupTarget);
        this.adminOtherInputTarget.value = text;
      }
    });

    this._syncAll();
  }

  _optionsOf(selectEl) {
    const set = new Set();
    Array.from(selectEl.options).forEach(o => set.add(o.text));
    return set;
  }

  _ensureOtherVisible(handle, groupEl) {
    const vals = handle.choices.getValue(true) || [];
    if (!vals.includes("Other")) {
      // add literal “Other” so the input shows
      handle.choices.setChoiceByValue("Other");
    }
    groupEl.style.display = "block";
  }

  // ---- Build the single column string + manage "Other" visibility ----
  _syncAll() {
    this._toggleOther(this.adult, this.adultOtherGroupTarget);
    this._toggleOther(this.juvenile, this.juvenileOtherGroupTarget);
    this._toggleOther(this.admin, this.adminOtherGroupTarget);

    const adultVals    = this._valuesFor(this.adult,    this.adultOtherInputTarget,    "Adult");
    const juvenileVals = this._valuesFor(this.juvenile, this.juvenileOtherInputTarget, "Juvenile");
    const adminVals    = this._valuesFor(this.admin,    this.adminOtherInputTarget,    "Administrative");

    const merged = [...adultVals, ...juvenileVals, ...adminVals]
      .map(s => s.trim())
      .filter(Boolean);

    if (this.combinedFieldTarget) this.combinedFieldTarget.value = merged.join(", ");
  }

  _toggleOther(handle, groupEl) {
    const vals = handle?.choices?.getValue(true) || [];
    const show = Array.isArray(vals) && vals.includes("Other");
    groupEl.style.display = show ? "block" : "none";
    if (!show) {
      const input = groupEl.querySelector("input");
      if (input) input.value = "";
    }
  }

  _valuesFor(handle, otherInput, label) {
    const vals = handle?.choices?.getValue(true) || [];
    const out = vals.filter(v => v !== "Other");
    const otherTxt = otherInput?.value?.trim();

    if (vals.includes("Other") && otherTxt) {
      out.push(`Other (${label}): ${otherTxt}`);
    }
    return out;
  }
}
