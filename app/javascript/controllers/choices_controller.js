// app/javascript/controllers/choices_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const ChoicesLib = window.Choices;
    if (!ChoicesLib) {
      console.error("Choices global not found (window.Choices is undefined)");
      return;
    }

    const placeholder =
      this.element.dataset.placeholder ||
      this.element.getAttribute("data-placeholder") ||
      this.element.getAttribute("placeholder") ||
      "Select options…";

    this.choices = new ChoicesLib(this.element, {
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
