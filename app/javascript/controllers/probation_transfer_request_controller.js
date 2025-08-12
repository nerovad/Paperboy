// app/javascript/controllers/probation_transfer_request_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["multiSelect", "otherGroup"];

  connect() {
    const ChoicesLib = window.Choices;
    if (!ChoicesLib) { console.error("Choices global not found"); return; }

    this.handleChange = this.toggleOtherField.bind(this);

    this.choices = new ChoicesLib(this.multiSelectTarget, {
      removeItemButton: true,
      placeholderValue: "Select Destination(s)",
      shouldSort: false
    });

    this.multiSelectTarget.addEventListener("change", this.handleChange);
    this.toggleOtherField();

    // After Choices builds the DOM, cache refs & wire events
    setTimeout(() => {
      this.wrapper  = this.multiSelectTarget.closest(".choices");
      this.dropdown = this.wrapper && this.wrapper.querySelector(".choices__list--dropdown");
      if (!this.dropdown || !this.wrapper) return;

      this._onShow   = () => this.fixDropdown();
      this._onHide   = () => this.resetDropdown();
      this._onReflow = () => this.positionDropdown();

      this.multiSelectTarget.addEventListener("showDropdown", this._onShow);
      this.multiSelectTarget.addEventListener("hideDropdown", this._onHide);
      window.addEventListener("scroll", this._onReflow, true);
      window.addEventListener("resize", this._onReflow);
    }, 0);
  }

  disconnect() {
    if (this.handleChange) this.multiSelectTarget.removeEventListener("change", this.handleChange);
    if (this._onShow)  this.multiSelectTarget.removeEventListener("showDropdown", this._onShow);
    if (this._onHide)  this.multiSelectTarget.removeEventListener("hideDropdown", this._onHide);
    window.removeEventListener("scroll", this._onReflow, true);
    window.removeEventListener("resize", this._onReflow);
    this.resetDropdown();
    if (this.choices && this.choices.destroy) this.choices.destroy();
  }

  // ---- “fixed” dropdown inside wrapper (so clicks still count) ----
  fixDropdown() {
    if (!this.dropdown || !this.wrapper) return;
    // Important: override any !important rules from CSS
    const setImp = (prop, val) => this.dropdown.style.setProperty(prop, val, "important");

    setImp("position", "fixed");
    setImp("z-index", "2147483647");
    setImp("right", "auto");
    this.positionDropdown();
  }

  positionDropdown() {
    if (!this.dropdown || !this.wrapper) return;
    const r = this.wrapper.getBoundingClientRect();
    const setImp = (prop, val) => this.dropdown.style.setProperty(prop, val, "important");
    setImp("left", `${Math.round(r.left)}px`);
    setImp("top",  `${Math.round(r.bottom)}px`);
    setImp("width", `${Math.round(r.width)}px`);
    setImp("box-sizing", "border-box");
    // Optional: constrain height
    setImp("max-height", "50vh");
    setImp("overflow", "auto");
  }

  resetDropdown() {
    if (!this.dropdown) return;
    this.dropdown.removeAttribute("style"); // clears the fixed positioning
  }

  // ---- Other field ----
  toggleOtherField() {
    const values = this.choices ? this.choices.getValue(true) : [];
    const show = Array.isArray(values) && values.indexOf("Other") !== -1;
    if (this.otherGroupTarget) {
      this.otherGroupTarget.style.display = show ? "block" : "none";
      if (show) {
        const input = this.otherGroupTarget.querySelector("input");
        if (input) input.focus();
      }
    }
  }
}
