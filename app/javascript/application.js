import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
import "form_navigation"
import { pbConfirm } from "pb_modal"

// Route every `data: { turbo_confirm: "…" }` through the shared Paperboy modal
// instead of the browser's "localhost says…" dialog. A view can override the
// heading with data-confirm-title; the confirm button turns red automatically
// when the control that triggered it is destructive.
Turbo.config.forms.confirm = (message, element, submitter) => {
  const source = submitter || element
  // .btn.deny is the standard; .btn.btn-danger is the legacy alias still used
  // by the form builder.
  const destructive = ["deny", "btn-danger"]
    .some((name) => source?.classList?.contains(name))

  return pbConfirm({
    title: source?.dataset?.confirmTitle || "Confirm",
    message,
    confirmLabel: source?.dataset?.confirmLabel || (destructive ? "Delete" : "Continue"),
    confirmVariant: destructive ? "deny" : "approve"
  })
}

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js");
}

document.addEventListener("turbo:load", () => {

  console.log("application.js loaded");
})
