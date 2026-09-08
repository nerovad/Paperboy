import { Controller } from "@hotwired/stimulus";

// Opens a modal showing one of a submission's histories — the workflow status
// timeline, or the field-level edit trail. The HTML is fetched on demand from
// the URL the trigger carries, so the inbox page itself stays light no matter
// how many rows it has, and adding a third history needs no change here.
//
// Trigger data attributes:
//   data-history-url    where to fetch the fragment from (required)
//   data-history-label  what kind of history this is (default "Status History")
//   data-record-title   which record it belongs to
export default class extends Controller {
  static targets = ["backdrop", "modal", "title", "body"];

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape") this.close(); };
    document.addEventListener("keydown", this._escHandler);
    this.element.addEventListener("click", (e) => {
      if (e.target === this.backdropTarget) this.close();
    });
  }

  disconnect() {
    document.removeEventListener("keydown", this._escHandler);
  }

  async open(event) {
    const trigger = event.currentTarget;
    const url = trigger.dataset.historyUrl;
    const label = trigger.dataset.historyLabel || "Status History";
    const title = trigger.dataset.recordTitle;

    this.titleTarget.textContent = title ? `${label}: ${title}` : label;
    this.bodyTarget.innerHTML = '<p class="history-modal__loading">Loading…</p>';
    this.backdropTarget.style.display = "flex";

    if (!url) return;

    try {
      const response = await fetch(url, {
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      });
      if (response.status === 403) throw new Error("forbidden");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      this.bodyTarget.innerHTML = await response.text();
    } catch (err) {
      this.bodyTarget.innerHTML =
        `<p class="history-modal__error">Could not load ${label.toLowerCase()}.</p>`;
    }
  }

  close() {
    this.backdropTarget.style.display = "none";
  }
}
