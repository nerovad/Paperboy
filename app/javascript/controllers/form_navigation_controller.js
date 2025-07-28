import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

  connect() {
    this.currentPage = 0;
    this.pages = document.querySelectorAll('.form-page');
    this.dots = document.querySelectorAll('.progress-dots .dot');
    this.showPage(this.currentPage);

    this.setupVehicleHandlers();
  }

  showPage(index) {
    this.pages.forEach((page, i) => {
      page.style.display = i === index ? 'block' : 'none';
      if (this.dots[i]) this.dots[i].classList.toggle('active', i === index);
    });

    if (this.submitButtonTarget) {
      this.submitButtonTarget.style.display = index === this.pages.length - 1 ? 'inline-block' : 'none';
    }

    const nextButton = document.querySelector('button[onclick="nextPage()"]');
    if (nextButton) nextButton.style.display = index === this.pages.length - 1 ? 'none' : 'inline-block';
  }

  nextPage() {
    if (this.currentPage < this.pages.length - 1) {
      this.currentPage++;
      this.showPage(this.currentPage);
    }
  }

  prevPage() {
    if (this.currentPage > 0) {
      this.currentPage--;
      this.showPage(this.currentPage);
    }
  }

  setupVehicleHandlers() {
    const wrapper = document.getElementById("vehicle-wrapper");
    const addBtn = document.getElementById("add-vehicle");
    const template = document.getElementById("vehicle-template");
    let vehicleIndex = 1;

    addBtn?.addEventListener("click", () => {
      const html = template.innerHTML.replace(/NEW_RECORD/g, vehicleIndex);
      wrapper.insertAdjacentHTML("beforeend", html);
      vehicleIndex++;
    });

    wrapper?.addEventListener("click", (e) => {
      if (e.target.classList.contains("remove-vehicle")) {
        const vehicleSet = e.target.closest(".vehicle-fields");
        vehicleSet.remove();
      }
    });

    wrapper?.addEventListener("change", (e) => {
      if (e.target.classList.contains("parking-lot-select")) {
        const group = e.target.closest(".vehicle-fields");
        const otherInput = group.querySelector(".other-lot-field");
        if (e.target.value === "Other") {
          otherInput.style.display = "block";
        } else {
          otherInput.style.display = "none";
          otherInput.value = "";
        }
      }
    });
  }
}
