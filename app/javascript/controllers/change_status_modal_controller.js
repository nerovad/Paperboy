import { Controller } from "@hotwired/stimulus";

// "Change Status" dialog on a submission's detail page (shared/_change_status).
//
// One instance per submission, so the form action and the options are already
// in the markup — this only shows and hides the shared .pb-modal shell.
export default class extends Controller {
  static targets = ["backdrop", "select"];

  connect() {
    this._escHandler = (e) => { if (e.key === "Escape") this.close(); };
    document.addEventListener("keydown", this._escHandler);
    this.backdropTarget.addEventListener("click", (e) => {
      if (e.target === this.backdropTarget) this.close();
    });
  }

  disconnect() { document.removeEventListener("keydown", this._escHandler); }

  open() {
    this.backdropTarget.hidden = false;
    if (this.hasSelectTarget) setTimeout(() => this.selectTarget.focus(), 0);
  }

  close() { this.backdropTarget.hidden = true; }
}
