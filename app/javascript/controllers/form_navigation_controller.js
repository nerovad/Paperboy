import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

 connect() {
  console.log("FormNavigationController connected");

  const form = this.element.querySelector("form");
  if (form) {
    // Observe unexpected display changes
    const observer = new MutationObserver(() => {
      console.log("Form style changed:", form.getAttribute("style"));
    });
    observer.observe(form, { attributes: true, attributeFilter: ["style"] });

    // Force visible in case Turbo renders it hidden
    requestAnimationFrame(() => {
      if (form.style.display === "none") {
        console.log("Form was hidden — un-hiding it now");
        form.style.display = "block";
      }
    });
  }

  this.pages = Array.from(this.element.querySelectorAll(".form-page"));
  console.log("Pages found:", this.pages.length, this.pages);

  this.current = 0;
  this.showCurrentPage();
  this.setupVehicleHandlers();
}

  disconnect() {
    console.log("FormNavigationController disconnected")
  }

  showCurrentPage() {
  console.log("Showing page:", this.current, "of", this.pages.length)

  this.pages.forEach((page, index) => {
    console.log("Page", index, "=>", index === this.current ? "SHOW" : "HIDE")
    page.style.display = index === this.current ? "" : "none";
  })

  if (this.submitButtonTarget) {
    this.submitButtonTarget.style.display = this.current === this.pages.length - 1 ? "" : "none"
  }
}

  nextPage() {
    if (this.current < this.pages.length - 1) {
      this.current++
      this.showCurrentPage()
    }
  }

  prevPage() {
    if (this.current > 0) {
      this.current--
      this.showCurrentPage()
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
