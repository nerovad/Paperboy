// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:load", () => {
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
});
