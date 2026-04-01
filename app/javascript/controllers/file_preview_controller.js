import { Controller } from "@hotwired/stimulus"

// Handles file preview for image and PDF uploads (supports multiple files)
export default class extends Controller {
  static targets = ["input", "preview"]

  preview(event) {
    const files = event.target.files
    const previewContainer = this.previewTarget

    if (!files.length) {
      previewContainer.innerHTML = ""
      return
    }

    previewContainer.innerHTML = ""

    Array.from(files).forEach((file) => {
      const wrapper = document.createElement("div")
      wrapper.className = "mt-3 p-3 border rounded"

      if (file.type.startsWith("image/")) {
        const reader = new FileReader()
        reader.onload = (e) => {
          wrapper.innerHTML = `
            <strong>Selected file:</strong> ${file.name}
            <div class="mt-3">
              <img src="${e.target.result}" style="max-width: 100%; max-height: 400px;" class="img-thumbnail" alt="Preview">
            </div>
          `
        }
        reader.readAsDataURL(file)
      } else if (file.type === "application/pdf") {
        wrapper.innerHTML = `
          <strong>Selected file:</strong> ${file.name}
          <div class="mt-3">
            <p class="text-muted">
              <i class="fas fa-file-pdf"></i> PDF Document selected
            </p>
          </div>
        `
      } else {
        wrapper.innerHTML = `
          <strong>Selected file:</strong> ${file.name}
          <p class="text-muted">File type: ${file.type}</p>
        `
      }

      previewContainer.appendChild(wrapper)
    })
  }
}
