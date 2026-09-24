import { Controller } from "@hotwired/stimulus"

// Upload: the person search shows only while "Someone else" is chosen.
export default class extends Controller {
  static targets = ["picker"]

  connect() {
    this.update()
  }

  update() {
    const chosen = this.element.querySelector("input[name=owner]:checked")
    const someoneElse = chosen?.value === "person"
    this.pickerTarget.hidden = !someoneElse
    const search = this.pickerTarget.querySelector("input[type=search]")
    if (search) search.required = someoneElse
  }
}
