import { Controller } from "@hotwired/stimulus"

// Handles file preview for image and PDF uploads
export default class extends Controller {
  static targets = ["input", "preview"]

  connect() {
    console.log("File preview controller connected")
  }

  preview(event) {
    const file = event.target.files[0]
    const previewContainer = this.previewTarget

    if (!file) {
      previewContainer.innerHTML = ""
      return
    }

    // Clear previous preview
    previewContainer.innerHTML = ""

    if (file.type.startsWith("image/")) {
      // Preview image
      const reader = new FileReader()
      reader.onload = (e) => {
        previewContainer.innerHTML = `
          <div class="mt-3 p-3 border rounded">
            <strong>Selected file:</strong> ${file.name}
            <div class="mt-3">
              <img src="${e.target.result}" style="max-width: 100%; max-height: 400px;" class="img-thumbnail" alt="Preview">
            </div>
          </div>
        `
      }
      reader.readAsDataURL(file)
    } else if (file.type === "application/pdf") {
      // Show PDF info (can't preview PDF in browser without additional libraries)
      previewContainer.innerHTML = `
        <div class="mt-3 p-3 border rounded">
          <strong>Selected file:</strong> ${file.name}
          <div class="mt-3">
            <p class="text-muted">
              <i class="fas fa-file-pdf"></i> PDF Document selected
            </p>
          </div>
        </div>
      `
    } else {
      // Show generic file info
      previewContainer.innerHTML = `
        <div class="mt-3 p-3 border rounded">
          <strong>Selected file:</strong> ${file.name}
          <p class="text-muted">File type: ${file.type}</p>
        </div>
      `
    }
  }
}
