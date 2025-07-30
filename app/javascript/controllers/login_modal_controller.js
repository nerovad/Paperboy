import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "loginBtn", "closeBtn", "form"]

  connect() {
    this.loginBtnTarget?.addEventListener("click", () => {
      this.modalTarget.style.display = "block"
    });

    this.closeBtnTarget?.addEventListener("click", () => {
      this.modalTarget.style.display = "none"
    });

    this.formTarget?.addEventListener("submit", async (e) => {
      e.preventDefault();
      const login = e.target.login.value;

      const res = await fetch("/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ login })
      });

      const data = await res.json();
      if (data.success) {
        location.reload();
      } else {
        alert("Login failed.");
      }
    });
  }
}
