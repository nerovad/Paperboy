// app/javascript/controllers/authorization_select_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "serviceType",
    "keyTypeWrapper",
    "keyType",
    "locationsWrapper",
    "locations",
    "allLocations",
  ];

  connect() {
    this.toggleFields();
  }

  // Key Type and Building/Locations only apply to Facility Keys (service
  // type 'K'); show them only when 'K' is among the selected service types.
  toggleFields() {
    const hasKey = this.selectedServiceTypes().includes("K");

    if (this.hasKeyTypeWrapperTarget) {
      this.keyTypeWrapperTarget.style.display = hasKey ? "" : "none";
    }
    if (this.hasLocationsWrapperTarget) {
      this.locationsWrapperTarget.style.display = hasKey ? "" : "none";
    }

    if (!hasKey) {
      // Clear key/location selections when 'K' is removed so hidden fields
      // don't submit stale values.
      if (this.hasKeyTypeTarget) {
        Array.from(this.keyTypeTarget.options).forEach((o) => (o.selected = false));
      }
      if (this.hasLocationsTarget) {
        Array.from(this.locationsTarget.options).forEach((o) => (o.selected = false));
      }
      if (this.hasAllLocationsTarget) {
        this.allLocationsTarget.checked = false;
      }
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
