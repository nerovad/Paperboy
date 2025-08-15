import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "title", "message"];

  connect() {
    this._originEvent = null;    // the click event we intercepted
    this._originForm = null;     // the form to submit on confirm
    this._originButton = null;   // the button that was clicked
    this._dateScope = document.querySelector("[data-controller='billing-tools']") || document;
  }

  open(event) {
    // Stop the submit for now
    event.preventDefault();
    event.stopPropagation();

    // Store origin
    this._originEvent = event;
    this._originButton = event.currentTarget;
    this._originForm = this._originButton.closest("form");

    // Read per-button title/message if provided
    const title = this._originButton.dataset.confirmTitle || "Confirm";
    const message = this._originButton.dataset.confirmMessage || "Are you sure you want to proceed?";

    this.titleTarget.textContent = title;
    this.messageTarget.textContent = message;

    // Show modal
    this.backdropTarget.style.display = "block";

    // ESC / click-out to cancel
    this._keydownHandler = (e) => { if (e.key === "Escape") this.cancel(); };
    document.addEventListener("keydown", this._keydownHandler);

    this._clickOutsideHandler = (e) => {
      if (e.target === this.backdropTarget) this.cancel();
    };
    this.backdropTarget.addEventListener("click", this._clickOutsideHandler);
  }

  cancel() {
    this._cleanup();
  }

  proceed() {
    // If this form expects s_date/e_date hidden fields (Monthly Billing), copy top inputs
    const sInput = this._dateScope.querySelector("[data-billing-tools-target='startDate']");
    const eInput = this._dateScope.querySelector("[data-billing-tools-target='endDate']");
    if (sInput && eInput && this._originForm) {
      const sHidden = this._originForm.querySelector("input[name='s_date']");
      const eHidden = this._originForm.querySelector("input[name='e_date']");
      if (sHidden && eHidden) {
        sHidden.value = sInput.value || "";
        eHidden.value = eInput.value || "";
      }
    }

    // Submit the original form
    if (this._originForm) this._originForm.submit();

    // Close modal
    this._cleanup();
  }

  _cleanup() {
    if (this.backdropTarget) this.backdropTarget.style.display = "none";
    if (this._keydownHandler) document.removeEventListener("keydown", this._keydownHandler);
    if (this._clickOutsideHandler) this.backdropTarget.removeEventListener("click", this._clickOutsideHandler);
    this._originEvent = null;
    this._originForm = null;
    this._originButton = null;
  }
}
