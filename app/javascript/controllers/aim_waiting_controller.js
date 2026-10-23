import { Controller } from "@hotwired/stimulus"
import { pbConfirm } from "pb_modal"

// Waiting for AI (#192): tick invoices, or the heading's box for every row
// the search leaves, then Hold, Release, Skip the AI, Reject or Delete them
// together. The boxes belong to the bulk form through form=. Hold, Release
// and Skip ask first here; Reject and Delete ask why in their own dialog
// (aim_reason_controller).
export default class extends Controller {
  static targets = ["check", "button", "count"]

  selectAll(event) {
    this.checkTargets.forEach((box) => {
      if (box.closest("tr").dataset.match !== "0") box.checked = event.currentTarget.checked
    })
    this.count()
  }

  count() {
    const n = this.checkTargets.filter((box) => box.checked).length
    this.countTarget.textContent = n
    this.buttonTargets.forEach((button) => { button.disabled = n === 0 })
  }

  async submit(event) {
    event.preventDefault()
    const button = event.currentTarget
    const n = this.checkTargets.filter((box) => box.checked).length
    const ok = await pbConfirm({ title: button.dataset.label, message: `${button.dataset.confirm} (${n} invoice${n === 1 ? "" : "s"})`,
                                 confirmLabel: button.dataset.label, confirmVariant: "approve" })
    if (!ok) return
    const form = button.form
    const field = form.querySelector("input[name=bulk_action]")
    field.value = button.value
    form.submit()
  }
}
