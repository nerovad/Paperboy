// app/javascript/controllers/tag_chips_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "chips", "hiddenField", "autocomplete"]
  static values = {
    existingTags: Array,
    tags: Array
  }

  connect() {
    this.tags = this.tagsValue || []
    this.renderChips()
    this.updateHiddenField()
  }

  tagsValueChanged() {
    this.tags = this.tagsValue || []
    this.renderChips()
    this.updateHiddenField()
  }

  handleKeydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.addTagFromInput()
    } else if (event.key === "Backspace" && this.inputTarget.value === "") {
      // Remove last tag if backspace pressed on empty input
      if (this.tags.length > 0) {
        this.tags.pop()
        this.renderChips()
        this.updateHiddenField()
      }
    } else if (event.key === "Escape") {
      this.hideAutocomplete()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.navigateAutocomplete(1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.navigateAutocomplete(-1)
    }
  }

  handleInput() {
    const value = this.inputTarget.value.trim().toLowerCase()

    if (value.length < 1) {
      this.hideAutocomplete()
      return
    }

    // Filter existing tags that match and aren't already selected
    const suggestions = this.existingTagsValue.filter(tag =>
      tag.toLowerCase().includes(value) && !this.tags.includes(tag)
    ).slice(0, 5)

    if (suggestions.length > 0) {
      this.showAutocomplete(suggestions)
    } else {
      this.hideAutocomplete()
    }
  }

  addTagFromInput() {
    const value = this.inputTarget.value.trim()
    if (value && !this.tags.includes(value)) {
      this.tags.push(value)
      this.renderChips()
      this.updateHiddenField()
    }
    this.inputTarget.value = ""
    this.hideAutocomplete()
  }

  addTagFromSuggestion(event) {
    const tag = event.currentTarget.dataset.tag
    if (tag && !this.tags.includes(tag)) {
      this.tags.push(tag)
      this.renderChips()
      this.updateHiddenField()
    }
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.hideAutocomplete()
  }

  removeTag(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.tags.splice(index, 1)
    this.renderChips()
    this.updateHiddenField()
  }

  renderChips() {
    this.chipsTarget.innerHTML = this.tags.map((tag, index) => `
      <span class="tag-chip">
        ${this.escapeHtml(tag)}
        <button type="button" class="tag-chip-remove" data-action="click->tag-chips#removeTag" data-index="${index}">&times;</button>
      </span>
    `).join("")
  }

  updateHiddenField() {
    this.hiddenFieldTarget.value = this.tags.join(",")
  }

  showAutocomplete(suggestions) {
    this.selectedIndex = -1
    this.autocompleteTarget.innerHTML = suggestions.map((tag, index) => `
      <div class="autocomplete-item" data-action="click->tag-chips#addTagFromSuggestion" data-tag="${this.escapeHtml(tag)}" data-index="${index}">
        ${this.escapeHtml(tag)}
      </div>
    `).join("")
    this.autocompleteTarget.style.display = "block"
  }

  hideAutocomplete() {
    this.autocompleteTarget.style.display = "none"
    this.selectedIndex = -1
  }

  navigateAutocomplete(direction) {
    const items = this.autocompleteTarget.querySelectorAll(".autocomplete-item")
    if (items.length === 0) return

    // Remove previous selection
    items.forEach(item => item.classList.remove("selected"))

    // Update index
    this.selectedIndex = this.selectedIndex + direction
    if (this.selectedIndex < 0) this.selectedIndex = items.length - 1
    if (this.selectedIndex >= items.length) this.selectedIndex = 0

    // Highlight new selection
    items[this.selectedIndex].classList.add("selected")

    // If Enter pressed while navigating, add the selected item
    this.inputTarget.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && this.selectedIndex >= 0) {
        e.preventDefault()
        items[this.selectedIndex].click()
      }
    }, { once: true })
  }

  handleBlur(event) {
    // Delay hiding to allow click on autocomplete items
    setTimeout(() => {
      this.hideAutocomplete()
    }, 200)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
