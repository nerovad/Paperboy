import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:load", () => {

console.log("application.js loaded");

  const multiSelect = document.querySelector(".choices-multiselect");
  if (multiSelect && !multiSelect.classList.contains("choices__input")) {
    new Choices(multiSelect, {
      removeItemButton: true,
      placeholderValue: 'Select parking lot(s)',
      shouldSort: false
    });
  }
});
