import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "modal", "form", "title", "taskType", "taskId", "employeeSelect"];

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
    const trigger = event.currentTarget;
    const taskType = trigger.dataset.taskType;
    const taskId = trigger.dataset.taskId;
    const currentAssignee = trigger.dataset.currentAssignee;

    // Set hidden fields
    this.taskTypeTarget.value = taskType;
    this.taskIdTarget.value = taskId;

    // Update title with formatted task type name
    const formattedType = taskType.replace(/([A-Z])/g, ' $1').trim();
    this.titleTarget.textContent = `Reassign ${formattedType}`;

    // Show modal
    this.backdropTarget.style.display = "flex";
    setTimeout(() => this.employeeSelectTarget.focus(), 0);
  }

  close() {
    this.backdropTarget.style.display = "none";
  }
}
