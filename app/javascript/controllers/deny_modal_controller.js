import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "modal", "form", "reason", "title"];

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape") this.close(); };
    document.addEventListener("keydown", this._escHandler);
    this.element.addEventListener("click", (e) => {
      if (e.target === this.backdropTarget) this.close();
    });
  }
  disconnect() { document.removeEventListener("keydown", this._escHandler); }

  open(event) {
    const trigger  = event.currentTarget;
    const denyPath = trigger.dataset.denyPath;
    const title    = trigger.dataset.recordTitle || "Deny";

    this.formTarget.action = denyPath;
    this.titleTarget.textContent = `Deny: ${title}`;
    this.reasonTarget.value = "";
    this.backdropTarget.style.display = "flex";
    setTimeout(() => this.reasonTarget.focus(), 0);
  }

  close() { this.backdropTarget.style.display = "none"; }
}
