import { Controller } from "@hotwired/stimulus"

// Generic repeating field-group ("repeating section") for generated forms.
//
// A hidden template block containing NEW_RECORD placeholders is cloned on Add;
// each clone is stamped with a fresh index so its nested-attributes input names
// are unique. Add/removeItem events bubble (unprefixed) so the surrounding
// conditional-fields controller re-evaluates any conditional fields inside the
// newly added/removed block — a gap the hand-built vehicle-list controller had.
//
// This is driven entirely by Stimulus targets/values (no hard-coded element
// ids) so the form builder can emit one section or many on the same form.
//
// Expected markup:
//   <div data-controller="repeatable-section"
//        data-repeatable-section-min-value="1"
//        data-repeatable-section-max-value="5">
//     <div data-repeatable-section-target="wrapper">
//       <!-- server-rendered .repeatable-block rows (existing records) -->
//     </div>
//     <template data-repeatable-section-target="template">
//       <div class="repeatable-block" data-block-index="NEW_RECORD"> … </div>
//     </template>
//     <button type="button" data-repeatable-section-target="addButton"
//             data-action="repeatable-section#add">+ Add</button>
//   </div>
//
// Remove buttons inside a block:
//   <button type="button" class="repeatable-remove-btn"
//           data-action="repeatable-section#remove">− Remove</button>
export default class extends Controller {
  static targets = ["wrapper", "template", "addButton"]
  static values = {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 0 }
  }

  connect() {
    this.index = this.nextIndex()
    this.enforceMin()
    this.updateControls()
  }

  // Existing rows may already carry data-block-index (edit view). Start numbering
  // clones after the highest one so we never collide with a persisted record.
  nextIndex() {
    const used = this.blocks()
      .map(b => parseInt(b.dataset.blockIndex, 10))
      .filter(n => !Number.isNaN(n))
    return used.length ? Math.max(...used) + 1 : 0
  }

  blocks() {
    if (!this.hasWrapperTarget) return []
    return Array.from(this.wrapperTarget.querySelectorAll(".repeatable-block"))
  }

  add(event) {
    event?.preventDefault()
    if (this.maxValue > 0 && this.blocks().length >= this.maxValue) return
    if (!this.hasTemplateTarget || !this.hasWrapperTarget) return

    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.index)
    this.wrapperTarget.insertAdjacentHTML("beforeend", html)
    this.index++
    this.updateControls()
    // Unprefixed so conditional-fields' addItem listener fires.
    this.dispatch("addItem", { bubbles: true, prefix: false })
  }

  remove(event) {
    const block = event.target.closest(".repeatable-block")
    if (!block || !this.wrapperTarget?.contains(block)) return
    event.preventDefault()
    if (this.blocks().length <= this.minValue) return

    block.remove()
    this.updateControls()
    this.dispatch("removeItem", { bubbles: true, prefix: false })
  }

  // Seed the minimum number of empty rows when the record has fewer (e.g. a
  // required section that must show one blank row on a fresh form).
  enforceMin() {
    let guard = 0
    while (this.blocks().length < this.minValue && guard < 50) {
      this.add()
      guard += 1
    }
  }

  // Disable Add at max; hide Remove buttons at min so the count can't dip below
  // the configured floor.
  updateControls() {
    const count = this.blocks().length

    if (this.hasAddButtonTarget && this.maxValue > 0) {
      this.addButtonTarget.disabled = count >= this.maxValue
    }

    const atMin = count <= this.minValue
    this.blocks().forEach(block => {
      block.querySelectorAll(".repeatable-remove-btn").forEach(btn => {
        btn.style.display = atMin ? "none" : ""
      })
    })
  }
}
