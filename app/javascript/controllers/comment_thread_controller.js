import { Controller } from "@hotwired/stimulus";
import { pbConfirm } from "pb_modal";

// A submission's comment thread, wherever it is rendered — inline on the
// submission's page or fetched into the inbox's history modal. Every form in
// the thread (the composer, each Delete) is posted here instead of navigating,
// and the server answers with the whole thread re-rendered, which replaces
// this element. The replacement connects a fresh controller, whose connect()
// brings every Comments button for the same submission up to date.
//
// Values:
//   key    "<ClassName>-<id>", matched against data-comment-count-key
//   count  how many comments the thread has
// A form carrying data-comment-thread-confirm asks before it is sent.
export default class extends Controller {
  static values = { key: String, count: Number };
  static targets = ["submit"];

  connect() {
    const label = this.countValue > 0 ? `Comments (${this.countValue})` : "Comments";
    document.querySelectorAll("[data-comment-count-key]").forEach((button) => {
      if (button.dataset.commentCountKey === this.keyValue) button.textContent = label;
    });
  }

  async submit(event) {
    event.preventDefault();
    const form = event.target;
    const question = form.dataset.commentThreadConfirm;

    if (question && !(await pbConfirm({ title: "Delete comment", message: question,
                                         confirmLabel: "Delete", confirmVariant: "deny" }))) return;

    if (this.hasSubmitTarget) this.submitTarget.disabled = true;

    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      });
      // 422 carries the thread back with the reason the comment was refused.
      if (!response.ok && response.status !== 422) throw new Error(`HTTP ${response.status}`);
      this.element.outerHTML = await response.text();
    } catch (err) {
      if (this.hasSubmitTarget) this.submitTarget.disabled = false;
      this.showError("Could not save that. Check your connection and try again.");
    }
  }

  showError(message) {
    let notice = this.element.querySelector(".comment-form__error");
    if (!notice) {
      notice = document.createElement("p");
      notice.className = "comment-form__error";
      notice.setAttribute("role", "alert");
      this.element.querySelector(".comment-form")?.prepend(notice);
    }
    notice.textContent = message;
  }
}
