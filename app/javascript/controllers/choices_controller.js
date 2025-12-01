// app/javascript/controllers/choices_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];

  connect() {
    const ChoicesLib = window.Choices;
    if (!ChoicesLib) {
      console.error("Choices global not found (window.Choices is undefined)");
      return;
    }

    if (!this.hasSelectTarget) return;

    const select = this.selectTarget;

    const placeholder =
      select.dataset.placeholder ||
      select.getAttribute("data-placeholder") ||
      select.getAttribute("placeholder") ||
      "Select options…";

    this.choices = new ChoicesLib(select, {
      removeItemButton: true,
      shouldSort: false,
      searchEnabled: true,
      allowHTML: false,
      placeholder: true,
      placeholderValue: placeholder
    });
  }

  disconnect() {
    if (this.choices && typeof this.choices.destroy === "function") {
      this.choices.destroy();
      this.choices = null;
    }
  }
}
