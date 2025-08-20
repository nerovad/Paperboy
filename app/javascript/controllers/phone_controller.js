import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "error"];

  connect() {
    // Guard in case targets weren't wired; fall back to element
    this.inputEl = this.hasInputTarget ? this.inputTarget : this.element;
    this.errorEl = this.hasErrorTarget ? this.errorTarget : null;

    // Basic attributes for UX
    this.inputEl.setAttribute("maxlength", "12"); // includes dashes
    this.inputEl.setAttribute("pattern", "\\d{3}-\\d{3}-\\d{4}");
    this.inputEl.setAttribute("autocomplete", "tel");
    this.inputEl.setAttribute("inputmode", "numeric");
  }

  format() {
    const digits = this.inputEl.value.replace(/\D/g, "").slice(0, 10);
    let out = digits;

    if (digits.length > 6) {
      out = `${digits.slice(0,3)}-${digits.slice(3,6)}-${digits.slice(6)}`;
    } else if (digits.length > 3) {
      out = `${digits.slice(0,3)}-${digits.slice(3)}`;
    }

    this.inputEl.value = out;
    // Clear any previous custom error while typing
    this._setValidity("", false);
  }

  validate() {
    const ok = /^\d{3}-\d{3}-\d{4}$/.test(this.inputEl.value);
    if (!ok && this.inputEl.value.trim() !== "") {
      this._setValidity("Enter a 10-digit phone number like 555-555-5555.", true);
    } else {
      this._setValidity("", false);
    }
    // Trigger browser tooltip on invalid
    this.inputEl.reportValidity();
  }

  _setValidity(message, isError) {
    this.inputEl.setCustomValidity(message);
    if (this.errorEl) {
      if (isError) {
        this.errorEl.textContent = message;
        this.errorEl.classList.add("active");
      } else {
        this.errorEl.textContent = "";
        this.errorEl.classList.remove("active");
      }
    }
    this.inputEl.classList.toggle("invalid", isError);
  }
}
