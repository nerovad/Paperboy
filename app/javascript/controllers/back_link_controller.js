import { Controller } from "@hotwired/stimulus";

// "← Back" in a page header (shared/_back_button).
//
// Steps back through the browser's history so the viewer lands on whatever list
// they came from — the inbox, Submissions, a search result — instead of a fixed
// destination. When there is no history to step back to (a link opened in a
// fresh tab or pasted in), this does nothing and the anchor's own href takes
// over.
export default class extends Controller {
  navigate(event) {
    if (window.history.length <= 1) return;

    event.preventDefault();
    window.history.back();
  }
}
