import { Controller } from "@hotwired/stimulus"

// Handles file preview for image and PDF uploads (supports multiple files)
// Accumulates files across selections and enforces a max file limit
export default class extends Controller {
  static targets = ["input", "preview", "count"]
  static values = { max: { type: Number, default: 10 } }

  connect() {
    this.selectedFiles = new DataTransfer()
  }

  preview() {
    const newFiles = Array.from(this.inputTarget.files)

    if (!newFiles.length) return

    // Check if adding these files would exceed the max
    const totalAfterAdd = this.selectedFiles.files.length + newFiles.length
    if (totalAfterAdd > this.maxValue) {
      alert(`You can upload a maximum of ${this.maxValue} files. You have ${this.selectedFiles.files.length} selected and tried to add ${newFiles.length} more.`)
      this.inputTarget.value = ""
      return
    }

    // Add new files to accumulated list
    newFiles.forEach(file => this.selectedFiles.items.add(file))

    // Replace input files with the full accumulated set
    this.inputTarget.files = this.selectedFiles.files

    this.renderPreviews()
  }

  removeFile(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    const updated = new DataTransfer()

    for (let i = 0; i < this.selectedFiles.files.length; i++) {
      if (i !== index) updated.items.add(this.selectedFiles.files[i])
    }

    this.selectedFiles = updated
    this.inputTarget.files = this.selectedFiles.files
    this.renderPreviews()
  }

  renderPreviews() {
    const files = Array.from(this.selectedFiles.files)
    const previewContainer = this.previewTarget

    // Update file count
    if (this.hasCountTarget) {
      this.countTarget.textContent = files.length > 0
        ? `${files.length} of ${this.maxValue} files selected`
        : ""
    }

    if (!files.length) {
      previewContainer.innerHTML = ""
      return
    }

    previewContainer.innerHTML = ""

    files.forEach((file, index) => {
      const wrapper = document.createElement("div")
      wrapper.className = "file-preview-item"

      const removeBtn = `<button type="button" class="file-preview-remove" data-action="click->file-preview#removeFile" data-index="${index}" title="Remove file">&times;</button>`

      if (file.type.startsWith("image/")) {
        const reader = new FileReader()
        reader.onload = (e) => {
          wrapper.innerHTML = `
            ${removeBtn}
            <img src="${e.target.result}" class="file-preview-thumb" alt="Preview">
            <span class="file-preview-name">${file.name}</span>
          `
        }
        reader.readAsDataURL(file)
      } else if (file.type === "application/pdf") {
        wrapper.innerHTML = `
          ${removeBtn}
          <div class="file-preview-icon"><i class="fas fa-file-pdf"></i></div>
          <span class="file-preview-name">${file.name}</span>
        `
      } else {
        wrapper.innerHTML = `
          ${removeBtn}
          <div class="file-preview-icon"><i class="fas fa-file"></i></div>
          <span class="file-preview-name">${file.name}</span>
        `
      }

      previewContainer.appendChild(wrapper)
    })
  }
}
