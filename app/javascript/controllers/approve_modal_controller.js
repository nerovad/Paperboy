// app/javascript/controllers/approve_modal_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "modal", "title", "form", "select"];

  static values = {
    approvePath: String, // optional defaults
    options: Array,
    title: String
  };

  open(event) {
    const btn = event.currentTarget;
    const approvePath = btn.dataset.approveModalApprovePathValue || "#";
    const title = btn.dataset.approveModalTitleValue || "Approve";
    const opts = JSON.parse(btn.dataset.approveModalOptionsValue || "[]");

    if (this.hasTitleTarget) this.titleTarget.textContent = title;
    if (this.hasFormTarget)  this.formTarget.action = approvePath;

    if (this.hasSelectTarget) {
      this.selectTarget.innerHTML = "";
      opts.filter(Boolean).forEach(o => {
        const opt = document.createElement("option");
        opt.value = o; opt.textContent = o;
        this.selectTarget.appendChild(opt);
      });
    }

    if (this.hasBackdropTarget) this.backdropTarget.style.display = "flex";
  }

  close() {
    if (this.hasBackdropTarget) this.backdropTarget.style.display = "none";
  }

}
