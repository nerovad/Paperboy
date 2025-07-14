import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:load", () => {

console.log("application.js loaded");
  // Slideshow logic
  const slides = document.querySelectorAll(".slide");
  console.log("Slides found:", slides.length);

  let current = 0;

  if (slides.length > 1) {
    setInterval(() => {
      slides[current].classList.remove("active");
      current = (current + 1) % slides.length;
      slides[current].classList.add("active");
    }, 10000);
  }

  const multiSelect = document.querySelector(".choices-multiselect");
  if (multiSelect && !multiSelect.classList.contains("choices__input")) {
    new Choices(multiSelect, {
      removeItemButton: true,
      placeholderValue: 'Select parking lot(s)',
      shouldSort: false
    });
  }
});
