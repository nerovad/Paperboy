import { Controller } from "@hotwired/stimulus"

const URGENCY_MAP = {
  "Elevator Outage (Entrapment)": "Immediate",
  "Elevator Outage (No Entrapment)": "Immediate",
  "Natural Disaster": "Immediate",
  "Unplanned Outage": "Immediate",
  "CEO Interest": "Earliest convenience",
  "Planned Outage": "Earliest convenience",
  "Safety Incident": "Earliest convenience",
  "HVAC": "Earliest convenience",
  "Approved Event Permit": "Before it happens",
  "Generator of Alarm Testing": "Before it happens",
  "Tree Removal": "Before it happens",
}

export default class extends Controller {
  static targets = ["incidentType", "urgency", "hiddenUrgency"]

  mapUrgency() {
    const incidentType = this.incidentTypeTarget.value
    if (!incidentType) return

    const keyword = URGENCY_MAP[incidentType]
    if (!keyword) return

    // Match option containing the keyword (handles both "Immediate" and "1 Immediate" formats)
    for (const option of this.urgencyTarget.options) {
      if (option.value.includes(keyword)) {
        this.urgencyTarget.value = option.value
        // Also update hidden field if present (for disabled selects that don't submit)
        if (this.hasHiddenUrgencyTarget) {
          this.hiddenUrgencyTarget.value = option.value
        }
        return
      }
    }
  }
}
