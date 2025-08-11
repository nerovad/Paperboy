// app/javascript/controllers/probation_transfer_request_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["multiSelect", "otherGroup"];

  connect() {
    console.log("Probation transfer request controller connected");

    const ChoicesLib = window.Choices;
    if (!ChoicesLib) {
      console.error("Choices global not found");
      return;
    }

    this.handleChange = this.toggleOtherField.bind(this);

    this.choices = new ChoicesLib(this.multiSelectTarget, {
      removeItemButton: true,
      placeholderValue: "Select Destination(s)",
      shouldSort: false
    });

    this.multiSelectTarget.addEventListener("change", this.handleChange);
    this.toggleOtherField();
  }

  disconnect() {
    if (this.handleChange) {
      this.multiSelectTarget.removeEventListener("change", this.handleChange);
    }
    if (this.choices && this.choices.destroy) {
      this.choices.destroy();
      this.choices = null;
    }
  }

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
