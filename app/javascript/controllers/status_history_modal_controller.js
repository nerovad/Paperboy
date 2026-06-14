import { Controller } from "@hotwired/stimulus";

// Opens a modal showing a submission's workflow status timeline. The timeline
// HTML is fetched on demand from the inbox#status_history endpoint, so the
// inbox page itself stays light no matter how many rows it has.
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
    const title = trigger.dataset.recordTitle || "Status History";

    this.titleTarget.textContent = `Status History: ${title}`;
    this.bodyTarget.innerHTML = '<p class="status-history-modal__loading">Loading…</p>';
    this.backdropTarget.style.display = "flex";

    if (!url) return;

    try {
      const response = await fetch(url, {
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      this.bodyTarget.innerHTML = await response.text();
    } catch (err) {
      this.bodyTarget.innerHTML =
        '<p class="status-history-modal__error">Could not load status history.</p>';
    }
  }

  close() {
    this.backdropTarget.style.display = "none";
  }
}
