import "@hotwired/turbo-rails"
import "controllers"
import "form_navigation"

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js");
}

document.addEventListener("turbo:load", () => {

  console.log("application.js loaded");
})
