import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

 connect() {
  console.log("FormNavigationController connected");

  this.form = this.element.querySelector("form") || this.element.closest("form") || this.element;
  if (this.form.tagName === "FORM") {
    // Disable native validation — we validate page-by-page ourselves
    this.form.setAttribute("novalidate", "")

    // Observe unexpected display changes
    const observer = new MutationObserver(() => {
      console.log("Form style changed:", this.form.getAttribute("style"));
    });
    observer.observe(this.form, { attributes: true, attributeFilter: ["style"] });

    // Force visible in case Turbo renders it hidden
    requestAnimationFrame(() => {
      if (this.form.style.display === "none") {
        console.log("Form was hidden — un-hiding it now");
        this.form.style.display = "block";
      }
    });

    // Intercept submit to handle hidden-page validation
    this.form.addEventListener("submit", (e) => this.handleSubmit(e));
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

  // Validate only the visible, enabled fields on the current page
  validateCurrentPage() {
    const page = this.pages[this.current]
    const fields = page.querySelectorAll("input, select, textarea")
    for (const field of fields) {
      // Skip disabled/hidden fields — they aren't submitted anyway
      if (field.disabled) continue
      if (!field.checkValidity()) {
        field.reportValidity()
        return false
      }
    }
    return true
  }

  // On submit, walk all pages and stop at the first one with invalid fields
  handleSubmit(e) {
    for (let i = 0; i < this.pages.length; i++) {
      // Temporarily show the page so the browser can focus invalid fields
      const wasHidden = this.pages[i].style.display === "none"
      if (wasHidden) this.pages[i].style.display = ""

      const fields = this.pages[i].querySelectorAll("input, select, textarea")
      for (const field of fields) {
        if (field.disabled) continue
        if (!field.checkValidity()) {
          e.preventDefault()
          this.current = i
          this.showCurrentPage()
          field.reportValidity()
          return
        }
      }

      // Re-hide if we showed it temporarily and it's not the target page
      if (wasHidden) this.pages[i].style.display = "none"
    }
    // All valid — let the submit proceed
  }

  nextPage() {
    if (this.current < this.pages.length - 1) {
      if (!this.validateCurrentPage()) return
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
