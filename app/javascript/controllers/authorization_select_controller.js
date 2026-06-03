// app/javascript/controllers/authorization_select_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["serviceType", "keyTypeWrapper", "keyType"];

  connect() {
    this.toggleFields();
  }

  toggleFields() {
    const values = this.selectedServiceTypes();
    const hasKey = values.includes("K");

    if (this.hasKeyTypeWrapperTarget) {
      this.keyTypeWrapperTarget.style.display = hasKey ? "" : "none";
    }
    if (!hasKey && this.hasKeyTypeTarget) {
      // clear any selected key types when 'K' is removed (multi-select)
      Array.from(this.keyTypeTarget.options).forEach((o) => (o.selected = false));
    }
  }

  selectedServiceTypes() {
    if (!this.hasServiceTypeTarget) return [];
    const sel = this.serviceTypeTarget;
    if (sel.multiple) {
      return Array.from(sel.selectedOptions).map((o) => o.value);
    }
    return sel.value ? [sel.value] : [];
  }
}
