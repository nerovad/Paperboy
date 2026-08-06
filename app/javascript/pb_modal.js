// Programmatic dialogs built from the shared .pb-modal markup in
// components/_modals.scss.
//
// Nothing in Paperboy should call window.confirm or window.alert — the browser
// renders those as "localhost says…" chrome, which looks nothing like the rest
// of the app. Use these instead:
//
//   import { pbConfirm, pbAlert } from "pb_modal"
//
//   if (await pbConfirm({ title: "Delete group", message: "…" })) { … }
//   await pbAlert({ message: "Could not save your changes." })
//
// application.js also wires pbConfirm into Turbo, so every
// `data: { turbo_confirm: "…" }` in a view renders this modal rather than the
// browser's.

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled])';

// Builds the shell and resolves with the value passed to whichever control the
// user activates. Cancelling — backdrop click, ✕, Escape — resolves false.
function openDialog({ title, message, buttons }) {
  return new Promise((resolve) => {
    const previouslyFocused = document.activeElement;

    const backdrop = document.createElement("div");
    backdrop.className = "pb-modal-backdrop";

    const panel = document.createElement("div");
    panel.className = "pb-modal";
    panel.setAttribute("role", "dialog");
    panel.setAttribute("aria-modal", "true");

    const header = document.createElement("div");
    header.className = "pb-modal__header";
    const heading = document.createElement("h3");
    heading.textContent = title;
    const closeButton = document.createElement("button");
    closeButton.type = "button";
    closeButton.className = "pb-modal__close";
    closeButton.setAttribute("aria-label", "Close");
    closeButton.textContent = "✕";
    header.append(heading, closeButton);

    const body = document.createElement("div");
    body.className = "pb-modal__body";
    // Split on blank lines so multi-paragraph messages keep their shape.
    const paragraphs = String(message ?? "").split(/\n{2,}/).filter((p) => p.trim());
    (paragraphs.length ? paragraphs : [String(message ?? "")]).forEach((text) => {
      const p = document.createElement("p");
      p.className = "pb-modal__message";
      p.textContent = text;
      body.appendChild(p);
    });

    const actions = document.createElement("div");
    actions.className = "pb-modal__actions";

    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      document.removeEventListener("keydown", onKeydown, true);
      backdrop.remove();
      if (previouslyFocused instanceof HTMLElement) previouslyFocused.focus();
      resolve(value);
    };

    buttons.forEach(({ label, className, value }) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = className;
      button.textContent = label;
      button.addEventListener("click", () => finish(value));
      actions.appendChild(button);
    });

    closeButton.addEventListener("click", () => finish(false));
    backdrop.addEventListener("click", (event) => {
      if (event.target === backdrop) finish(false);
    });

    // Escape closes; Tab cycles inside the dialog so focus can't wander behind
    // the backdrop. Capture phase so a page-level Escape handler doesn't win.
    const onKeydown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        finish(false);
        return;
      }
      if (event.key !== "Tab") return;

      const focusable = Array.from(panel.querySelectorAll(FOCUSABLE));
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", onKeydown, true);

    panel.append(header, body, actions);
    backdrop.appendChild(panel);
    document.body.appendChild(backdrop);

    // Focus the affirmative control — the last one in the row.
    const defaultFocus = actions.lastElementChild;
    if (defaultFocus instanceof HTMLElement) defaultFocus.focus();
  });
}

// Replaces window.confirm. Resolves true only if the user confirms.
export function pbConfirm({
  title = "Confirm",
  message = "Are you sure you want to proceed?",
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  confirmVariant = "approve",
} = {}) {
  return openDialog({
    title,
    message,
    buttons: [
      { label: cancelLabel, className: "btn", value: false },
      { label: confirmLabel, className: `btn ${confirmVariant}`.trim(), value: true },
    ],
  });
}

// Replaces window.alert. Resolves once the user dismisses it.
export function pbAlert({ title = "Notice", message = "", buttonLabel = "OK" } = {}) {
  return openDialog({
    title,
    message,
    buttons: [{ label: buttonLabel, className: "btn approve", value: true }],
  });
}
