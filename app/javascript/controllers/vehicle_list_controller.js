import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.wrapper = document.getElementById("vehicle-wrapper")
    this.template = document.getElementById("vehicle-template")
    this.addBtn = document.getElementById("add-vehicle")
    if (!this.wrapper || !this.template || !this.addBtn) return

    const existingIndices = Array.from(this.wrapper.querySelectorAll(".vehicle-block"))
      .map(b => parseInt(b.dataset.vehicleIndex, 10))
      .filter(n => !isNaN(n))
    this.vehicleIndex = existingIndices.length ? Math.max(...existingIndices) + 1 : 0

    this.handleAdd = () => {
      const idx = this.vehicleIndex
      const vehicleHtml = this.template.innerHTML.replace(/NEW_RECORD/g, idx)
      this.wrapper.insertAdjacentHTML("beforeend", vehicleHtml)
      this.vehicleIndex++
      this.relocateAddBtn()
    }

    this.handleRemove = (event) => {
      if (!event.target.classList.contains("remove-vehicle-btn")) return
      const block = event.target.closest(".vehicle-block")
      if (!block) return
      // Evacuate +Add if it lives in the block we're about to remove.
      if (block.contains(this.addBtn)) {
        this.wrapper.appendChild(this.addBtn)
      }
      block.remove()
      this.relocateAddBtn()
    }

    this.addBtn.addEventListener("click", this.handleAdd)
    this.wrapper.addEventListener("click", this.handleRemove)
  }

  relocateAddBtn() {
    const blocks = this.wrapper?.querySelectorAll(".vehicle-block")
    if (!blocks || blocks.length === 0) return
    const lastBlock = blocks[blocks.length - 1]
    const actions = lastBlock.querySelector(".vehicle-row-actions")
    if (actions && this.addBtn && actions !== this.addBtn.parentElement) {
      actions.appendChild(this.addBtn)
    }
  }

  disconnect() {
    this.addBtn?.removeEventListener("click", this.handleAdd)
    this.wrapper?.removeEventListener("click", this.handleRemove)
  }
}
