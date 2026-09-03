// app/javascript/controllers/choices_controller.js
import { Controller } from "@hotwired/stimulus";
import { choicesOptions } from "choices_setup";

export default class extends Controller {
  static targets = ["select"];

  connect() {
    if (this.element.closest("#vehicle-template")) return;

    const ChoicesLib = window.Choices;
    if (!ChoicesLib) {
      console.error("Choices global not found (window.Choices is undefined)");
      return;
    }

    if (!this.hasSelectTarget) return;

    const select = this.selectTarget;

    // An empty <select> is not a state Choices complains about — it builds the
    // widget and quietly renders its "No choices to choose from" placeholder,
    // which looks identical whether the server sent no options or this markup is
    // a snapshot taken while a previous instance held them (see teardown below).
    // The server half is silent too: FormLookup#lookup_rows rescues a failed
    // lookup to []. Neither end says anything, so say it here.
    if (select.options.length === 0) {
      console.warn(
        `Choices: initialising "${select.name || select.id || "unnamed select"}" with no ` +
        `options — it will render "No choices to choose from".`
      );
    }

    const placeholder =
      select.dataset.placeholder ||
      select.getAttribute("data-placeholder") ||
      select.getAttribute("placeholder") ||
      "Select options…";

    this.choices = new ChoicesLib(select, choicesOptions({
      removeItemButton: true,
      shouldSort: false,
      searchEnabled: true,
      placeholder: true,
      placeholderValue: placeholder
    }));

    // Choices moves every <option> into its own store and leaves the real
    // <select> empty (WrappedSelect#appendDocFragment sets innerHTML = ""), and
    // only destroy() puts them back. Turbo takes its cache snapshot while
    // controllers are still connected — before disconnect() runs — so without
    // this the cached copy keeps the emptied <select>, and every restore from it
    // builds a dropdown with nothing in it. Tear down before the snapshot is
    // taken and let connect() build it again on the way back in.
    // form_navigation_controller#buildRail guards the same hazard for its rail.
    this.beforeCache = () => this.teardown();
    document.addEventListener("turbo:before-cache", this.beforeCache);
  }

  disconnect() {
    if (this.beforeCache) {
      document.removeEventListener("turbo:before-cache", this.beforeCache);
      this.beforeCache = null;
    }

    this.teardown();
  }

  // Destroy the instance if one is live, restoring the original <option>s to the
  // underlying <select>. Safe to call twice: the second call is a no-op.
  teardown() {
    if (this.choices && typeof this.choices.destroy === "function") {
      this.choices.destroy();
      this.choices = null;
    }
  }
}
