import { Controller } from "@hotwired/stimulus"
import { pbAlert } from "pb_modal"

// Amounts are checked before the review form is sent (#166), by the rules
// Aim::MoneyAttributes saves by: thousands commas, a dollar sign, spaces and
// accounting parentheses are fine; anything else stops the send, says which
// field and why, and leaves everything typed where it is. The server checks
// again and, if it refuses, shows the form back as typed.
const AMOUNT = /^-?(\d+(\.\d*)?|\.\d+)$/
const GROUPED = /^-?\d{1,3}(,\d{3})+(\.\d*)?$/
const LIMIT = 1e13

export function readableAmount(value) {
  let text = value.trim()
  if (text === "") return true

  if (text.startsWith("(") && text.endsWith(")")) text = text.slice(1, -1)
  text = text.replace(/[$ ]/g, "")
  if (text.includes(",") && !GROUPED.test(text)) return false

  text = text.replace(/,/g, "")
  return AMOUNT.test(text) && Math.abs(parseFloat(text)) < LIMIT
}

export default class extends Controller {
  static targets = ["field"]

  check(event) {
    const bad = this.fieldTargets.filter((field) => !field.disabled && !readableAmount(field.value))
    this.fieldTargets.forEach((field) => field.classList.toggle("is-invalid", bad.includes(field)))
    if (bad.length === 0) return

    event.preventDefault()
    event.stopImmediatePropagation()
    const lines = bad.map((field) => `${field.dataset.label}: "${field.value.trim()}"`)
    pbAlert({
      title: "Not saved",
      message: `${lines.join("; ")} ${bad.length === 1 ? "is not an amount" : "are not amounts"} AIM can save. ` +
               "Use digits, with commas and a $ if you like (1,234.50). Everything else you typed is still here."
    }).then(() => bad[0].focus())
  }

  // Typing in a field clears its mark.
  fieldTargetConnected(field) {
    field.addEventListener("input", () => field.classList.remove("is-invalid"))
  }
}
