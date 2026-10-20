import { Controller } from "@hotwired/stimulus"

// A menu item that presses another button (#182): the review page's More menu
// lists rare actions whose real buttons stay where they were, hidden, with
// their dialogs, confirmations and form. Closes the menu first.
//
//   <button type="button" data-action="aim-press#press" data-aim-press-target-param="aim-act-reject">Reject…</button>
export default class extends Controller {
  press(event) {
    event.preventDefault()
    event.currentTarget.closest("details")?.removeAttribute("open")
    document.getElementById(event.params.target)?.click()
  }
}
