// app/javascript/controllers/search_command_controller.js
//
// Runs a search command by dispatching the window event named on the row.
//
// The row and the thing it opens are deliberately unacquainted: "Who Am I"
// appears in the sidebar and in the command palette, and its dialog lives in
// the layout, out of reach of either. A window event is how the rest of the
// app already talks across that distance — see the account hierarchy card's
// `coa-organization-selected@window`.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  run(event) {
    const name = event.currentTarget.dataset.commandEvent
    if (!name) return

    window.dispatchEvent(new CustomEvent(name))
  }
}
