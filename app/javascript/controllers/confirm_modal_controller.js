import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "modal", "form", "message", "title"];

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

  open(event) {
    event.preventDefault();
    const trigger = event.currentTarget;
    const deletePath = trigger.dataset.deletePath;
    const message = trigger.dataset.confirmMessage || "Are you sure?";
    const title = trigger.dataset.confirmTitle || "Confirm";

    this.formTarget.action = deletePath;
    this.titleTarget.textContent = title;
    this.messageTarget.textContent = message;
    this.backdropTarget.style.display = "flex";
  }

  close() {
    this.backdropTarget.style.display = "none";
  }
}
