import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]

  connect() {
    this.current = 0;

    if (this.slideTargets.length > 1) {
      this.interval = setInterval(() => {
        this.showNextSlide();
      }, 10000);
    }
  }

  disconnect() {
    clearInterval(this.interval);
  }

  showNextSlide() {
    this.slideTargets[this.current].classList.remove("active");
    this.current = (this.current + 1) % this.slideTargets.length;
    this.slideTargets[this.current].classList.add("active");
  }
}
