import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// An agency group's report columns (#131): drag a column to move it. Each
// row is a checkbox in the form, and the form posts the ticked ones in the
// order they stand, so the order on screen is the report's.
export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, { animation: 150, handle: ".aim-column-order__handle" })
  }

  disconnect() {
    this.sortable?.destroy()
  }
}
